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
        
        let config = ModelConfiguration(schema: schema, url: storeURL)
        
        do {
            return try ModelContainer(for: schema, configurations: config)
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
                    print("[SwiftData] Store URL: \(MLXVoiceNotesApp.storeURL.path)")
                    
                    let context = Self.modelContainer.mainContext
                    do {
                        let scriptCount = try context.fetchCount(FetchDescriptor<Script>())
                        let voiceCount = try context.fetchCount(FetchDescriptor<VoiceProfile>())
                        print("[SwiftData] Scripts: \(scriptCount), VoiceProfiles: \(voiceCount)")
                    } catch {
                        print("[SwiftData] Failed to count: \(error)")
                    }
                    #endif
                }
        }
        .modelContainer(Self.modelContainer)
        .windowResizability(.contentMinSize)
    }
}
