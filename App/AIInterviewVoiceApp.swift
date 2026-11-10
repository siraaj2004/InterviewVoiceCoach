import SwiftUI

/// AI Interview Voice Coach — v1.3.0 build 7, bundle com.shaik.aiinterviewvoice, iOS 16+.
/// v1.1 adds video body observation (front camera + Vision pose, on-device only).
/// v1.2 adds the correct-me loop: live body correction banner while answering,
/// one combined spoken correction (answer + body), and the same question asked
/// again after a wrong answer.
/// v1.3 fixes the black camera preview (preview layer is now the view's own
/// layer) and adds a front/back camera switch + a plain message when the
/// camera cannot start.
/// v1.4 makes the Video tab camera full-screen (front or back, switchable),
/// with badges on top and controls in a translucent bottom panel, and
/// starts observation as soon as the tab opens.
/// v1.6 fixes the "Camera not available" error coming back on shaik's phone
/// (Interview tab, Q3 #19, 2026-11-10): stop() now fully releases the camera
/// (inputs AND outputs), start() builds a fresh video output every time,
/// and the Interview camera is full-screen like the Video tab. The
/// correct-me loop now speaks through the loudspeaker, re-asks the same
/// question, and starts the mic by itself for the retry answer.
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
