import SwiftUI

/// AI Interview Voice Coach — v1.1.0 build 4, bundle com.shaik.aiinterviewvoice, iOS 16+.
/// v1.1 adds video body observation (front camera + Vision pose, on-device only).
/// Build 4 fix: renamed the `body` service property to `bodyService` — it
/// collided with SwiftUI View's `body` and broke run #3's build.
/// Real human-voice interviewer asks AI Engineer questions, the user answers by
/// speaking, wrong/partial answers are corrected by voice, and every answer gets
/// an English-accuracy score (fillers, grammar, pace) + a content score.
/// On-device only: no server, no login, no audio upload. History stays on the phone.
@main
struct AIInterviewVoiceApp: App {
    @StateObject private var store = InterviewStore()
    @StateObject private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(speech)
                .onAppear { speech.requestPermissions() }
        }
    }
}
