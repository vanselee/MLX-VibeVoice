import Foundation

// MARK: - HTTP Range File Downloader

/// Standalone single-file downloader with HTTP Range-based resume.
///
/// Design principles:
/// - Uses `URLSessionDataTask` (not `URLSessionDownloadTask`) for streaming writes via `FileHandle`
/// - `.partial` temp file: append data as it arrives
/// - Resume: reads `.partial` size, sets `Range: bytes=<size>-`
///   - HTTP 206 → append
///   - HTTP 200 → server ignores Range → reset, download from 0
/// - On completion: verify file size, atomically move `.partial` → final file
/// - No dependency on Hugging Face, ResourceCenterView, or model manifests
///
/// Usage:
/// ```swift
/// let downloader = HTTPRangeFileDownloader(
///     url: URL(string: "https://example.com/file.bin")!,
///     destination: documentsDir.appendingPathComponent("file.bin")
/// )
/// downloader.onProgress = { progress in print("\(Int(progress * 100))%") }
/// downloader.onSpeed = { bps in print("\(bps / 1024) KB/s") }
/// downloader.onComplete = { error in
///     if let error { print("Failed: \(error)") }
///     else { print("Done") }
/// }
/// downloader.start()
/// // downloader.cancel() to stop
/// ```
final class HTTPRangeFileDownloader: NSObject {

    // MARK: - Types

    /// Downloader state
    enum State: Equatable {
        case idle
        case downloading
        case completed
        case failed(String)
    }

    /// Download-specific errors
    enum DownloadError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int)
        case remoteFileUnavailable(String)
        case fileWriteFailed
        case fileMoveFailed(String)
        case cancelled
        case sizeMismatch(expected: Int64, actual: Int64)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的 URL"
            case .httpError(let code):
                return "HTTP 错误 \(code)"
            case .remoteFileUnavailable(let message):
                return message
            case .fileWriteFailed:
                return "文件写入失败"
            case .fileMoveFailed(let path):
                return "文件移动失败: \(path)"
            case .cancelled:
                return "下载已取消"
            case .sizeMismatch(let expected, let actual):
                return "文件大小不匹配: 期望 \(ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)), 实际 \(ByteCountFormatter.string(fromByteCount: actual, countStyle: .file))"
            }
        }
    }

    // MARK: - Public Properties

    let url: URL
    let destinationURL: URL
    let partialURL: URL

    /// Progress callback (0.0…1.0)
    var onProgress: ((Double) -> Void)?

    /// Speed callback (bytes per second)
    var onSpeed: ((Int64) -> Void)?

    /// Completion callback. `nil` error on success.
    var onComplete: ((Error?) -> Void)?

    /// State change callback
    var onStateChange: ((State) -> Void)?

    /// Callback fired when the GET request starts receiving data (after HEAD succeeds and server responds 200/206).
    /// NOT fired during HEAD phase.
    var onDownloadStarted: (() -> Void)?

    /// Current state
    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    /// Bytes downloaded so far
    private(set) var downloadedBytes: Int64 = 0

    /// Total expected bytes (0 if unknown)
    private(set) var totalBytes: Int64 = 0

    /// Current download speed (bytes/sec)
    private(set) var currentSpeed: Int64 = 0

    // MARK: - Private Properties

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var resumeOffset: Int64 = 0
    private var pendingError: Error?

    private var speedTimer: Timer?
    private var lastSpeedCheckBytes: Int64 = 0
    private var lastSpeedCheckTime = Date()

    // MARK: - Initialization

    /// Create a downloader for a single file.
    /// - Parameters:
    ///   - url: Remote file URL
    ///   - destination: Local file path (final destination after download)
    init(url: URL, destination: URL) {
        self.url = url
        self.destinationURL = destination
        self.partialURL = destination.appendingPathExtension("partial")
        super.init()
    }

    // MARK: - Public API

    /// Start (or resume) the download.
    func start() {
        guard state == .idle || state == .failed(DownloadError.cancelled.errorDescription ?? "") || {
            if case .failed = state { return true }
            return false
        }() else { return }

        // Determine resume offset from existing .partial file
        if let attrs = try? FileManager.default.attributesOfItem(atPath: partialURL.path),
           let size = attrs[.size] as? Int64, size > 0 {
            resumeOffset = size
        } else {
            resumeOffset = 0
        }

        // Step 1: HEAD request to get total file size
        fetchRemoteFileSize()
    }

    /// Cancel the download. The `.partial` file is retained for potential resume.
    func cancel() {
        task?.cancel()
        tearDown()
        state = .failed(DownloadError.cancelled.errorDescription ?? "已取消")
    }

    // MARK: - Private: HEAD Request

    private func fetchRemoteFileSize() {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            if let error = error {
                self.state = .failed(error.localizedDescription)
                self.onComplete?(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let error = DownloadError.remoteFileUnavailable("HEAD 请求失败: 无效响应")
                self.state = .failed(error.localizedDescription)
                self.onComplete?(error)
                return
            }

            guard httpResponse.statusCode == 200 else {
                let error = DownloadError.remoteFileUnavailable("远程文件不存在或无法访问：HTTP \(httpResponse.statusCode)")
                self.state = .failed(error.localizedDescription)
                self.onComplete?(error)
                return
            }

            let contentLength = Int64(httpResponse.expectedContentLength)
            self.totalBytes = contentLength > 0 ? contentLength : 0

            // Step 2: Start the actual data download
            self.beginDataDownload()
        }.resume()
    }

    // MARK: - Private: Data Download

    private func beginDataDownload() {
        let fm = FileManager.default

        // If resuming and .partial doesn't exist (edge case), reset offset
        if resumeOffset > 0 && !fm.fileExists(atPath: partialURL.path) {
            resumeOffset = 0
        }

        // Ensure .partial exists (create empty if fresh start)
        if !fm.fileExists(atPath: partialURL.path) {
            fm.createFile(atPath: partialURL.path, contents: nil)
        }

        // Open FileHandle for append writes
        guard let fh = FileHandle(forWritingAtPath: partialURL.path) else {
            let error = DownloadError.fileWriteFailed
            state = .failed(error.localizedDescription)
            onComplete?(error)
            return
        }

        if resumeOffset > 0 {
            // Append mode — seek to end
            try? fh.seekToEnd()
        } else {
            // Fresh start — truncate
            try? fh.truncate(atOffset: 0)
        }

        fileHandle = fh
        downloadedBytes = resumeOffset

        // Build request with Range header if resuming
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }

        // Create a dedicated session with delegate callbacks
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        task = session?.dataTask(with: request)

        state = .downloading
        onDownloadStarted?()

        // Speed tracking timer (fires every second)
        lastSpeedCheckBytes = downloadedBytes
        lastSpeedCheckTime = Date()
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.calculateSpeed()
        }

        task?.resume()
    }

    // MARK: - Speed Calculation

    private func calculateSpeed() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSpeedCheckTime)
        guard elapsed >= 0.5 else { return }

        let bytesSinceLast = downloadedBytes - lastSpeedCheckBytes
        currentSpeed = Int64(Double(bytesSinceLast) / elapsed)
        onSpeed?(currentSpeed)

        lastSpeedCheckBytes = downloadedBytes
        lastSpeedCheckTime = now
    }

    // MARK: - Completion

    private func finishDownload() {
        speedTimer?.invalidate()
        speedTimer = nil
        fileHandle?.closeFile()
        fileHandle = nil
        session?.invalidateAndCancel()
        session = nil

        let fm = FileManager.default

        // Verify partial file exists and has correct size
        guard let partialSize = try? fm.attributesOfItem(atPath: partialURL.path)[.size] as? Int64 else {
            state = .failed("下载完成但 .partial 文件不可读")
            onComplete?(DownloadError.fileWriteFailed)
            return
        }

        // Size validation (skip if totalBytes is unknown / 0)
        if totalBytes > 0 && partialSize != totalBytes {
            state = .failed(DownloadError.sizeMismatch(expected: totalBytes, actual: partialSize).errorDescription ?? "大小不匹配")
            onComplete?(DownloadError.sizeMismatch(expected: totalBytes, actual: partialSize))
            return
        }

        // Atomically move .partial → final file
        do {
            // Remove stale destination if it exists
            try? fm.removeItem(at: destinationURL)
            try fm.moveItem(at: partialURL, to: destinationURL)
            state = .completed
            onComplete?(nil)
        } catch {
            state = .failed(DownloadError.fileMoveFailed(error.localizedDescription).errorDescription ?? "移动失败")
            onComplete?(error)
        }
    }

    // MARK: - Teardown

    private func tearDown() {
        speedTimer?.invalidate()
        speedTimer = nil
        fileHandle?.closeFile()
        fileHandle = nil
        session?.invalidateAndCancel()
        session = nil
    }
}

// MARK: - URLSessionDataDelegate

extension HTTPRangeFileDownloader: URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = DownloadError.remoteFileUnavailable("无效的 HTTP 响应")
            pendingError = error
            state = .failed(error.localizedDescription)
            completionHandler(.cancel)
            return
        }

        switch httpResponse.statusCode {
        case 200:
            // Server returned full content (ignoring Range header).
            // Reset and download from the beginning.
            if resumeOffset > 0 {
                resumeOffset = 0
                downloadedBytes = 0
                try? fileHandle?.truncate(atOffset: 0)
                try? fileHandle?.seek(toOffset: 0)
            }
            // If HEAD failed and we still don't know the total size, use Content-Length
            if totalBytes == 0 {
                totalBytes = Int64(httpResponse.expectedContentLength)
            }
            completionHandler(.allow)

        case 206:
            // Partial Content — correct resume behavior. Append to .partial.
            completionHandler(.allow)

        default:
            let error = DownloadError.httpError(statusCode: httpResponse.statusCode)
            pendingError = error
            state = .failed(error.localizedDescription)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {

        guard let fh = fileHandle else {
            let error = DownloadError.fileWriteFailed
            pendingError = error
            state = .failed("文件句柄丢失")
            task?.cancel()
            return
        }

        do {
            try fh.write(contentsOf: data)
            downloadedBytes += Int64(data.count)

            // Report progress (clamped to 1.0, degrades gracefully if totalBytes is 0)
            let progress: Double
            if totalBytes > 0 {
                progress = min(Double(downloadedBytes) / Double(totalBytes), 1.0)
            } else {
                progress = 0
            }
            onProgress?(progress)
        } catch {
            pendingError = error
            state = .failed("写入 .partial 失败: \(error.localizedDescription)")
            task?.cancel()
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {

        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                let failure = pendingError
                tearDown()
                if let failure {
                    pendingError = nil
                    onComplete?(failure)
                }
                return
            }
            state = .failed(error.localizedDescription)
            tearDown()
            onComplete?(error)
            return
        }

        finishDownload()
    }
}
