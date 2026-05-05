import Foundation

// MARK: - Schema Version Tracking

/// Tracks schema version via UserDefaults to detect upgrades and trigger backups.
enum ModelVersion {
    /// Current schema version. Increment when adding new non-optional fields or new models.
    /// SwiftData lightweight migration handles: new Optional fields, new fields with defaults,
    /// new models, renamed properties. No custom MigrationPlan needed for these cases.
    static let current: Int = 1

    private static let versionKey = "com.vanselee.MLXVoiceNotes.schemaVersion"

    /// Last known schema version stored in UserDefaults. Returns 0 if never set.
    static var stored: Int {
        UserDefaults.standard.integer(forKey: versionKey)
    }

    /// Whether the schema has been upgraded since last launch.
    static var isUpgrade: Bool {
        stored > 0 && stored < current
    }

    /// Whether this is the first launch (no stored version).
    static var isFirstLaunch: Bool {
        stored == 0
    }

    /// Record the current schema version to UserDefaults.
    static func record() {
        UserDefaults.standard.set(current, forKey: versionKey)
        #if DEBUG
        print("[SchemaMigration] Version recorded: \(current)")
        #endif
    }
}

// MARK: - Store Backup

enum StoreBackup {
    /// Backup SwiftData store files before potential schema migration.
    /// Only runs when a schema version upgrade is detected.
    /// - Parameter storeURL: The main .store file URL
    /// - Returns: URL of the backup directory, or nil if backup was not needed / failed
    @discardableResult
    static func backupIfNeeded(storeURL: URL) -> URL? {
        guard ModelVersion.isUpgrade else {
            #if DEBUG
            if ModelVersion.isFirstLaunch {
                print("[StoreBackup] First launch, no existing store to backup.")
            } else {
                print("[StoreBackup] Schema version unchanged (\(ModelVersion.current)), skipping backup.")
            }
            #endif
            return nil
        }

        let fileManager = FileManager.default

        // Backup directory: Application Support/MLX Voice Notes/Backups/
        let backupDir = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Backup subdirectory: MLXVoiceNotes_<timestamp>/
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let storeBaseName = storeURL.deletingPathExtension().lastPathComponent
        let backupName = "\(storeBaseName)_\(timestamp)"
        let backupSubDir = backupDir.appendingPathComponent(backupName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: backupSubDir, withIntermediateDirectories: true)

            // Copy all store-related files
            let storeDir = storeURL.deletingLastPathComponent()
            let baseName = storeURL.deletingPathExtension().lastPathComponent
            let extensions = ["store", "store-shm", "store-wal"]

            var backedUpCount = 0
            for ext in extensions {
                let source = storeDir.appendingPathComponent("\(baseName).\(ext)")
                if fileManager.fileExists(atPath: source.path) {
                    let dest = backupSubDir.appendingPathComponent(source.lastPathComponent)
                    try fileManager.copyItem(at: source, to: dest)
                    backedUpCount += 1
                }
            }

            #if DEBUG
            print("[StoreBackup] ✅ Backup created: \(backupSubDir.lastPathComponent) (\(backedUpCount) files)")
            print("[StoreBackup] Schema version: \(ModelVersion.stored) → \(ModelVersion.current)")
            #endif

            return backupSubDir
        } catch {
            #if DEBUG
            print("[StoreBackup] ❌ Backup failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// List existing backup directories, sorted by modification date (newest first).
    static func listBackups(storeURL: URL) -> [URL] {
        let backupDir = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.hasDirectoryPath }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aDate > bDate
            }
    }
}
