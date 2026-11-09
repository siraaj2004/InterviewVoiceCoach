import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: InterviewStore
    @EnvironmentObject private var speech: SpeechService
    @State private var testText = "Hello, I am your AI interview coach. Tell me about yourself in one minute."
    var body: some View {
        NavigationView {
            Form {
                Section("Interviewer voice — real human voice") {
                    Picker("Voice", selection: $store.selectedVoiceId) {
                        Text("Best available (auto)").tag(nil as String?)
                        ForEach(SpeechService.availableVoices(), id: \.identifier) { v in
                            Text("\(v.name) (\(v.language), \(v.quality == .enhanced ? "enhanced" : "default"))").tag(v.identifier as String?)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Speed: \(String(format: "%.2f", store.speechRate))")
                        Slider(value: $store.speechRate, in: 0.35...0.65, step: 0.01)
                    }
                    Button("Test voice") {
                        speech.speechRate = Float(store.speechRate)
                        speech.voiceIdentifier = store.selectedVoiceId
                        speech.speak(testText)
                    }
                    Text("For the most human voice: iPhone Settings → Accessibility → Spoken Content → Voices → English (US) → download an Enhanced voice, then pick it here.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Practice") {
                    Toggle("Show ideal answer before I answer", isOn: $store.showIdealBeforeAnswer)
                    Text("Leave this off for a real interview feel — the correction comes by voice after you answer.")
                        .font(.footnote).foregroundColor(.secondary)
                    Toggle("Ask the question again after a correction", isOn: $store.autoReaskAfterCorrection)
                    Text("When your answer is wrong, the app corrects you by voice, then asks the same question again so you can try it right away.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Privacy") {
                    Text("No account, no server, no upload. Your voice is recognised on your iPhone and your history stays on your phone. Microphone and Speech Recognition are used only while you are answering.")
                        .font(.footnote).foregroundColor(.secondary)
                    Text("Permissions: \(speech.permissionStatus)")
                        .font(.footnote).foregroundColor(.secondary)
                    Button("Ask permissions again") { speech.requestPermissions() }
                }
                Section("About") {
                    Text("AI Interview Voice Coach v1.4.0 (build 8) • 59 questions, 10 topics • AI Engineer interview practice • Video body check is on-device only — no video recorded or uploaded")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.speechRate) { v in speech.speechRate = Float(v) }
            .onChange(of: store.selectedVoiceId) { v in speech.voiceIdentifier = v }
        }
    }
}
