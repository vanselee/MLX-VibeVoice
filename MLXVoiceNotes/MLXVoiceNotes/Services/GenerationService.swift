import Foundation

/// Phase 0.5: 真实音频生成服务
/// - 点击生成音频时创建 Task，按段串行生成
/// - 不使用 Timer 调度
/// - 每段生成完成后保存到 App 持久化目录
enum GenerationService {
    /// 当前正在生成的文案 ID（防止重复启动）
    static var currentlyGeneratingScriptID: UUID?

    /// 活跃任务句柄字典，用于真正取消/暂停 Task
    static var activeTaskByScriptID: [UUID: Task<Void, Never>] = [:]

    /// MLX 音频服务实例（共享）
    static var mlxService = MLXAudioService()

    // MARK: - Public API

    /// 开始生成（用户点击"生成音频"按钮时调用）
    /// - Parameters:
    ///   - script: 要生成的文案
    ///   - voiceInstruct: 可选的 voice instruct 文本（如 "中文女声，自然、清晰、适合旁白"）
    ///   - completion: 生成完成回调（成功或失败）
    static func start(script: Script, voiceInstruct: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // 防止重复启动
        guard currentlyGeneratingScriptID == nil else {
            completion?(.failure(GenerationError.alreadyGenerating))
            return
        }

        guard script.status != .generating else {
            completion?(.failure(GenerationError.alreadyGenerating))
            return
        }

        // 重置所有段落状态，但保留已完成段落的 generatedAudioPath
        resetSegmentsForFullRegenerate(for: script)
        script.status = .generating
        script.updatedAt = .now
        currentlyGeneratingScriptID = script.id

        // 创建后台 Task 串行生成，存入字典以便取消
        let task = Task {
            do {
                try await generateAllSegments(script: script, voiceInstruct: voiceInstruct)
                await MainActor.run {
                    script.status = .completed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.success(()))
                }
            } catch is CancellationError {
                await MainActor.run {
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                }
            } catch {
                await MainActor.run {
                    script.status = .failed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.failure(error))
                }
            }
        }
        activeTaskByScriptID[script.id] = task
    }

    /// 暂停生成（用户点击"暂停"按钮）
    static func pause(script: Script) {
        guard script.status == .generating else { return }

        // 取消正在运行的 Task
        if let task = activeTaskByScriptID[script.id] {
            task.cancel()
            activeTaskByScriptID.removeValue(forKey: script.id)
        }

        for segment in script.segments where segment.status == .generating {
            segment.status = .pending
        }
        script.status = .ready
        script.updatedAt = .now
        currentlyGeneratingScriptID = nil
    }

    /// 取消生成（用户点击"取消"按钮）
    static func cancel(script: Script) {
        // 取消正在运行的 Task
        if let task = activeTaskByScriptID[script.id] {
            task.cancel()
            activeTaskByScriptID.removeValue(forKey: script.id)
        }

        // 已完成的段落保持 completed，其余回 pending
        for segment in script.segments where segment.status != .completed {
            segment.status = .pending
        }
        script.status = .draft
        script.updatedAt = .now
        currentlyGeneratingScriptID = nil
    }

    /// 重试失败段落
    static func retryFailedSegments(script: Script, voiceInstruct: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard currentlyGeneratingScriptID == nil else {
            completion?(.failure(GenerationError.alreadyGenerating))
            return
        }

        // 只重置失败段落
        for segment in script.segments where segment.status == .failed {
            segment.status = .pending
        }

        script.status = .generating
        script.updatedAt = .now
        currentlyGeneratingScriptID = script.id

        let task = Task {
            do {
                try await generateAllSegments(script: script, voiceInstruct: voiceInstruct)
                await MainActor.run {
                    script.status = .completed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.success(()))
                }
            } catch is CancellationError {
                await MainActor.run {
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                }
            } catch {
                await MainActor.run {
                    script.status = .failed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.failure(error))
                }
            }
        }
        activeTaskByScriptID[script.id] = task
    }

    /// 重试单个段落
    static func retry(segment: ScriptSegment, in script: Script, voiceInstruct: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard currentlyGeneratingScriptID == nil else {
            completion?(.failure(GenerationError.alreadyGenerating))
            return
        }

        segment.status = .pending
        script.status = .generating
        script.updatedAt = .now
        currentlyGeneratingScriptID = script.id

        let task = Task {
            do {
                try await generateAllSegments(script: script, voiceInstruct: voiceInstruct)
                await MainActor.run {
                    script.status = .completed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.success(()))
                }
            } catch is CancellationError {
                await MainActor.run {
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                }
            } catch {
                await MainActor.run {
                    script.status = .failed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.failure(error))
                }
            }
        }
        activeTaskByScriptID[script.id] = task
    }

    /// 继续生成（用户点击"继续生成"按钮）
    static func resume(script: Script, voiceInstruct: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard currentlyGeneratingScriptID == nil else {
            completion?(.failure(GenerationError.alreadyGenerating))
            return
        }

        let pendingSegments = script.segments.filter { $0.status == .pending }
        guard !pendingSegments.isEmpty else {
            // 没有待生成段落，检查是否全部完成
            if script.segments.allSatisfy({ $0.status == .completed }) {
                script.status = .completed
            }
            completion?(.success(()))
            return
        }

        script.status = .generating
        script.updatedAt = .now
        currentlyGeneratingScriptID = script.id

        let task = Task {
            do {
                try await generateAllSegments(script: script, voiceInstruct: voiceInstruct)
                await MainActor.run {
                    script.status = .completed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.success(()))
                }
            } catch is CancellationError {
                await MainActor.run {
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                }
            } catch {
                await MainActor.run {
                    script.status = .failed
                    script.updatedAt = .now
                    currentlyGeneratingScriptID = nil
                    activeTaskByScriptID.removeValue(forKey: script.id)
                    completion?(.failure(error))
                }
            }
        }
        activeTaskByScriptID[script.id] = task
    }

    /// 根据段落角色查找对应的 VoiceProfile
    /// - 参数:
    ///   - segment: 目标段落
    ///   - script: 段落所属文案（含 roles 关系）
    ///   - voiceProfiles: 当前环境中所有可用音色
    /// - 返回: 匹配的 VoiceProfile 或 nil（未找到时返回 nil）
    /// - 注意: 最小实现，仅做字符串匹配，不调用 MLXAudioService
    static func resolveVoiceProfile(
        for segment: ScriptSegment,
        in script: Script,
        from voiceProfiles: [VoiceProfile]
    ) -> VoiceProfile? {
        // 1. 用 segment.roleName 匹配 VoiceRole.name 或 normalizedName
        let matchedRole: VoiceRole? = script.roles.first {
            $0.name == segment.roleName || $0.normalizedName == segment.roleName
        }

        guard let voiceRole = matchedRole else {
            return nil
        }

        // 2. 用 voiceRole.defaultVoiceName 匹配 VoiceProfile.name
        return voiceProfiles.first { $0.name == voiceRole.defaultVoiceName }
    }

    // MARK: - Private Implementation

    /// 串行生成所有待生成段落
    private static func generateAllSegments(script: Script, voiceInstruct: String?) async throws {
        let orderedSegments = script.segments.sorted { $0.order < $1.order }

        for segment in orderedSegments {
            // 检查段落状态
            guard segment.status == .pending else { continue }

            // 检查是否被暂停或取消
            guard script.status == .generating else { break }

            // 检查 Task 是否被取消（pause/cancel 会调用 task.cancel()）
            try Task.checkCancellation()

            // 标记当前段落为生成中
            await MainActor.run {
                segment.status = .generating
                script.updatedAt = .now
            }

            do {
                // 调用 MLXAudioService 生成音频
                let tempURL = try await mlxService.generateAudio(
                    text: segment.text,
                    voice: voiceInstruct,
                    language: "zh"
                )

                // 复制到持久化目录
                let persistentURL = try AudioStorageService.persistAudioFile(
                    tempURL: tempURL,
                    for: script.id,
                    segmentID: segment.id
                )

                // 保存相对路径到段落
                let relativePath = AudioStorageService.relativePath(from: persistentURL)

                await MainActor.run {
                    segment.generatedAudioPath = relativePath
                    segment.status = .completed
                    script.updatedAt = .now
                }

                // 删除临时文件
                try? FileManager.default.removeItem(at: tempURL)

            } catch {
                await MainActor.run {
                    segment.status = .failed
                    script.updatedAt = .now
                }
                // 继续生成下一个段落（不抛出错误，允许部分失败）
                print("[GenerationService] Segment \(segment.order) failed: \(error.localizedDescription)")
            }
        }
    }

    private static func resetSegments(for script: Script) {
        for segment in script.segments {
            segment.status = .pending
            segment.generatedAudioPath = nil
        }
    }

    /// 重置段落状态用于全部重新生成
    /// 全部重置为 pending，保留 generatedAudioPath 直到被新生成覆盖
    /// 注意：如果用户在重新生成过程中取消，已重新生成的段落保留新音频
    private static func resetSegmentsForFullRegenerate(for script: Script) {
        for segment in script.segments {
            segment.status = .pending
            // 保留 generatedAudioPath — 重新生成成功后会覆盖
            // 取消时，已完成的旧文件仍存在，但段落状态为 pending（可重新生成）
        }
    }
}

// MARK: - Errors

enum GenerationError: Error, LocalizedError {
    case alreadyGenerating
    case noPendingSegments
    case audioGenerationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyGenerating:
            return "已有文案正在生成中"
        case .noPendingSegments:
            return "没有待生成的段落"
        case .audioGenerationFailed(let error):
            return "音频生成失败：\(error.localizedDescription)"
        }
    }
}
