import SwiftData
import SwiftUI

@main
struct MLXVoiceNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Script.self,
            ScriptSegment.self,
            VoiceRole.self,
            VoiceProfile.self,
            GenerationJob.self,
            ExportRecord.self
        ])
        .windowResizability(.contentMinSize)
    }
}
