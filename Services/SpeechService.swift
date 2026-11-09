import Foundation
import AVFoundation
import Speech
import Combine

/// Real human-voice interviewer (on-device iOS voices) + live speech recognition.
/// No audio leaves the phone. TTS uses the best installed en-US voice —
/// enhanced / neural voices (e.g. Samantha, Daniel) when downloaded in
/// Settings > Accessibility > Spoken Content > Voices, otherwise the
/// default en-US voice. This is a real human voice, not a robotic beep.
@MainActor
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var isListening = false
    @Published var liveTranscript = ""
    @Published var lastListenDuration: Double = 0
    @Published var permissionStatus = "Not checked"
    @Published var lastError: String?

    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var onFinal: ((String, Double) -> Void)?
    private var listenStart: Date?

    var speechRate: Float = 0.48
    var voiceIdentifier: String? // nil = system default en-US

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Permissions
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                self.permissionStatus = status == .authorized ? "Speech: allowed" : "Speech: \(status.rawValue) — allow in Settings"
            }
        }
        // iOS 16-compatible: AVAudioApplication.requestRecordPermission is iOS 17+ only
        // and broke the iOS 16.0 build (run #1). AVAudioSession works on iOS 16.
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
    }

    private func bestVoice() -> AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        // Prefer enhanced / neural quality voices first.
        return voices.first(where: { $0.quality == .enhanced })
            ?? voices.first(where: { $0.name.contains("Samantha") })
            ?? voices.first(where: { $0.name.contains("Daniel") })
            ?? voices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: Speak (interviewer + correction)
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice()
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        // Keep a reference so completion fires once.
        speakCompletion = completion
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    private var speakCompletion: (() -> Void)?

    func stopSpeaking() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
        speakCompletion = nil
    }

    // Delegate methods are nonisolated (AVSpeechSynthesizerDelegate is not
    // MainActor); hop back to the main actor to touch @Published state.
    // This silences the main-actor warnings seen in run #1.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            let cb = self.speakCompletion; self.speakCompletion = nil; cb?()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false; self.speakCompletion = nil
        }
    }

    // MARK: Listen (user answer)
    func startListening(onFinal: @escaping (String, Double) -> Void) {
        self.onFinal = onFinal
        liveTranscript = ""
        listenStart = Date()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { lastError = "Audio session: \(error.localizedDescription)"; return }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        let input = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    if result.isFinal { self.finishListening() }
                }
                if error != nil { self.finishListening() }
            }
        }
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { lastError = "Mic start: \(error.localizedDescription)"; return }
        isListening = true
    }

    func stopListening() { finishListening() }

    private func finishListening() {
        let duration = listenStart.map { Date().timeIntervalSince($0) } ?? 0
        lastListenDuration = duration
        let text = liveTranscript
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil; recognitionTask = nil
        isListening = false
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            onFinal?(text, duration)
        }
        onFinal = nil
    }
}
