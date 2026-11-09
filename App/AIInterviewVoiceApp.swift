import SwiftUI

/// AI Interview Voice Coach — v1.0.0 build 2, bundle com.shaik.aiinterviewvoice, iOS 16+.
/// Build 2 fix: AVAudioSession.requestRecordPermission (iOS 16) instead of
/// AVAudioApplication (iOS 17+ only) — run #1 failed on that line.
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
