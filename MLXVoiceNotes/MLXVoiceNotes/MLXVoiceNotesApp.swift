import SwiftData
import SwiftUI

@main
struct MLXVoiceNotesApp: App {
    // MARK: - SwiftData Store Configuration
    static let storeURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MLX Voice Notes", isDirectory: true)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("MLXVoiceNotes.store")
    }()
    
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ])

        // MARK: Pre-migration Backup
        // Backup store files if schema version has been upgraded.
        // This runs BEFORE ModelContainer creation to capture the pre-migration state.
        StoreBackup.backupIfNeeded(storeURL: storeURL)

        // SwiftData lightweight migration is enabled by default.
        // It handles: new Optional fields, new fields with default values,
        // new models, and property renames. No custom MigrationPlan needed.
        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: config)
            // Record current schema version after successful container creation.
            ModelVersion.record()
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // MARK: - Startup Diagnostics
                    #if DEBUG
                    let ctx = Self.modelContainer.mainContext

                    // Store & version info
                    print("[Startup] Store URL: \(MLXVoiceNotesApp.storeURL.path)")
                    print("[Startup] Schema version: \(ModelVersion.current) (stored: \(ModelVersion.stored))")
                    print("[Startup] Model types: Script, ScriptSegment, VoiceRole, VoiceProfile, GenerationJob, ExportRecord")

                    // Record counts
                    do {
                        let scriptCount = try ctx.fetchCount(FetchDescriptor<Script>())
                        let segCount    = try ctx.fetchCount(FetchDescriptor<ScriptSegment>())
                        let roleCount   = try ctx.fetchCount(FetchDescriptor<VoiceRole>())
                        let voiceCount  = try ctx.fetchCount(FetchDescriptor<VoiceProfile>())
                        let jobCount    = try ctx.fetchCount(FetchDescriptor<GenerationJob>())
                        let exportCount = try ctx.fetchCount(FetchDescriptor<ExportRecord>())
                        print("[Startup] Records — Scripts: \(scriptCount), Segments: \(segCount), Roles: \(roleCount), VoiceProfiles: \(voiceCount), Jobs: \(jobCount), Exports: \(exportCount)")
                    } catch {
                        print("[Startup] ⚠️ Failed to count records: \(error)")
                    }

                    // Backup inventory
                    let backups = StoreBackup.listBackups(storeURL: MLXVoiceNotesApp.storeURL)
                    if backups.isEmpty {
                        print("[Startup] Backups: none")
                    } else {
                        print("[Startup] Backups (\(backups.count)): \(backups.map { $0.lastPathComponent }.joined(separator: ", "))")
                    }
                    #endif
                }
        }
        .modelContainer(Self.modelContainer)
        .windowResizability(.contentMinSize)
    }
}
