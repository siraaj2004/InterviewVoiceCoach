import SwiftUI

struct InterviewView: View {
    @EnvironmentObject private var store: InterviewStore
    @EnvironmentObject private var speech: SpeechService
    // v1.1: video body observation (front camera + Vision, on-device only).
    @StateObject private var bodyService = BodyLanguageService()
    @State private var videoBodyOn = true
    @State private var lastBody: BodyLanguageResult?

    @State private var queue: [InterviewQuestion] = []
    @State private var index = 0
    @State private var started = false
    @State private var lastEvaluation: Evaluation?
    @State private var showingResult = false
    @State private var answeredCount = 0

    private var current: InterviewQuestion? { queue.isEmpty ? nil : queue[index] }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !started { setupCard } else if let q = current { questionCard(q) }
                    if started, let q = current { answerCard(q) }
                    if let ev = lastEvaluation, showingResult { resultCard(ev) }
                }
                .padding()
            }
            .navigationTitle("Voice Interview")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.selectedTopic) { _ in if !started { rebuildQueue() } }
            .onAppear { if queue.isEmpty { rebuildQueue() } }
        }
    }

    // MARK: Setup
    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start a voice interview").font(.title2.bold())
            Text("The interviewer speaks the question. You answer by speaking.").foregroundColor(.secondary)
            Picker("Topic", selection: $store.selectedTopic) {
                ForEach(Topic.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            Picker("Mode", selection: $store.mode) {
                ForEach(InterviewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Video body check — watch posture, eyes & movement while you answer", isOn: $videoBodyOn)
            Text("Front camera only, on this phone. No video is recorded, saved or uploaded.")
                .font(.footnote).foregroundColor(.secondary)
            Text("\(QuestionBank.questions(for: store.selectedTopic).count) questions in this topic • \(store.mode == .mock ? "Mock: 5 random questions" : "Practice: go one by one, shuffled")")
                .font(.footnote).foregroundColor(.secondary)
            Button { startSession() } label: {
                Label("Start interview — voice on", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }
            Text(speech.permissionStatus).font(.footnote).foregroundColor(.secondary)
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    // MARK: Question
    private func questionCard(_ q: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(q.topic.rawValue).font(.caption.bold()).padding(6).background(Color.blue.opacity(0.15)).cornerRadius(8)
                Text(q.difficulty.rawValue).font(.caption).padding(6).background(Color.green.opacity(0.15)).cornerRadius(8)
                Spacer()
                Text("Q \(index + 1)\(store.mode == .mock ? " / 5" : " • #\(q.id)")").font(.caption).foregroundColor(.secondary)
            }
            Text(q.question).font(.title3.bold())
            HStack(spacing: 10) {
                Button { speech.speak(q.question) } label: {
                    Label(speech.isSpeaking ? "Speaking…" : "Hear question", systemImage: "speaker.wave.2.fill")
                }.buttonStyle(.borderedProminent).disabled(speech.isSpeaking)
                Button("Repeat") { speech.speak(q.question) }.buttonStyle(.bordered)
                Button("Next") { nextQuestion() }.buttonStyle(.bordered)
            }
            if store.showIdealBeforeAnswer {
                Text("Ideal: \(q.idealAnswer)").font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    // MARK: Answer
    private func answerCard(_ q: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your answer — speak it").font(.headline)
            if videoBodyOn && bodyService.isObserving {
                CameraPreview(session: bodyService.captureSession)
                    .frame(height: 170).cornerRadius(12)
                HStack(spacing: 8) {
                    Text("Posture: \(bodyService.livePosture)").font(.caption.bold())
                    Text("Eyes: \(bodyService.liveEye)").font(.caption.bold())
                    Text("Move: \(bodyService.liveMovement)").font(.caption.bold())
                }
                Text(bodyService.personVisible ? "Camera can see you — keep head and shoulders in frame." : "Camera cannot see you yet — sit in frame, good light on your face.")
                    .font(.caption).foregroundColor(.secondary)
                // v1.2: live body correction while you answer — on screen only,
                // never spoken live, or the mic would hear it and transcribe it.
                if let banner = bodyCorrectionBanner {
                    Text(banner).font(.subheadline.bold())
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2)).cornerRadius(10)
                }
            }
            if speech.isListening {
                Text(speech.liveTranscript.isEmpty ? "Listening… speak now" : speech.liveTranscript)
                    .font(.body).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08)).cornerRadius(10)
            } else if !speech.liveTranscript.isEmpty {
                Text(speech.liveTranscript).font(.body).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground)).cornerRadius(10)
            }
            HStack(spacing: 10) {
                if speech.isListening {
                    Button { finishAnswer(for: q) } label: {
                        Label("Stop & Check", systemImage: "checkmark.circle.fill")
                    }.buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button { speech.speak(q.question); startListening() } label: {
                        Label("Tap mic & answer", systemImage: "mic.fill")
                    }.buttonStyle(.borderedProminent)
                }
                if speech.isSpeaking {
                    Button("Stop voice") { speech.stopSpeaking() }.buttonStyle(.bordered)
                }
            }
            Text("Tip: answer in 2–3 full sentences. Avoid um / uh — pause silently instead.")
                .font(.footnote).foregroundColor(.secondary)
            Button("End session") { endSession() }.font(.footnote).foregroundColor(.red)
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    // MARK: Result
    private func resultCard(_ ev: Evaluation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ev.verdict).font(.headline)
            Text(ev.overallLabel).font(.subheadline).foregroundColor(.secondary)
            HStack(spacing: 12) {
                ScoreRing(label: "Overall", score: ev.overallScore, color: .blue)
                ScoreRing(label: "Content", score: ev.contentScore, color: .green)
                ScoreRing(label: "English", score: ev.englishScore, color: .orange)
                if let bs = ev.bodyScore {
                    ScoreRing(label: "Body", score: bs, color: .purple)
                }
            }
            if let evBody = lastBody, ev.bodyScore != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Body language — \(evBody.postureLabel) • Eyes: \(evBody.eyeLabel) • Movement: \(evBody.movementLabel) (\(evBody.personVisiblePercent)% visible)").font(.subheadline)
                    ForEach(evBody.tips, id: \.self) { Text("• \($0)").font(.subheadline) }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Your answer (\(ev.transcript.split(separator: " ").count) words, \(ev.wordsPerMinute) words/min, \(ev.fillerCount) fillers)").font(.caption).foregroundColor(.secondary)
                Text("“\(ev.transcript)”").font(.subheadline).italic()
            }
            if !ev.missingKeywords.isEmpty {
                Text("Missing ideas: \(ev.missingKeywords.joined(separator: ", "))").font(.subheadline).foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("English tips").font(.subheadline.bold())
                ForEach(ev.englishTips, id: \.self) { Text("• \($0)").font(.subheadline) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Correct answer").font(.subheadline.bold())
                Text(ev.correctedAnswer).font(.subheadline)
            }
            HStack(spacing: 10) {
                Button { speech.speak(ev.correctedAnswer) } label: {
                    Label(speech.isSpeaking ? "Speaking…" : "Hear correction", systemImage: "speaker.wave.2.fill")
                }.buttonStyle(.borderedProminent).disabled(speech.isSpeaking)
                Button("Try again") { retrySameQuestion() }.buttonStyle(.bordered)
                Button("Next question") { nextQuestion() }.buttonStyle(.bordered)
            }
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    /// v1.2: the live body correction shown while answering.
    private var bodyCorrectionBanner: String? {
        if bodyService.livePosture == "Slouched" { return "⚠️ Sit upright — shoulders back, head level." }
        if bodyService.liveEye == "Looking away" { return "⚠️ Look at the camera — eye contact matters." }
        if bodyService.liveMovement == "Fidgety" { return "⚠️ Keep your hands still — too much movement distracts." }
        return nil
    }

    // MARK: Flow
    private func rebuildQueue() {
        queue = QuestionBank.questions(for: store.selectedTopic).shuffled()
        index = 0
    }
    private func startSession() {
        rebuildQueue()
        if store.mode == .mock { queue = Array(queue.prefix(5)) }
        started = true; answeredCount = 0; lastEvaluation = nil; showingResult = false
        speech.speechRate = Float(store.speechRate)
        speech.voiceIdentifier = store.selectedVoiceId
        if let q = current { speech.speak("Question \(index + 1). \(q.question)") }
    }
    private func startListening() {
        speech.speechRate = Float(store.speechRate)
        speech.voiceIdentifier = store.selectedVoiceId
        if videoBodyOn { bodyService.start() }
        speech.startListening { _, _ in }
    }
    private func finishAnswer(for q: InterviewQuestion) {
        let text = speech.liveTranscript
        speech.stopListening()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Real measured listen duration from SpeechService; fall back to a
        // 130 wpm pace estimate only if the measurement is missing.
        let duration = speech.lastListenDuration > 0 ? speech.lastListenDuration : Double(text.split(separator: " ").count) / 130 * 60
        var ev = EvaluationEngine.evaluate(question: q, transcript: text, durationSeconds: duration)
        // v1.1: stop the camera observation and attach the body result.
        if videoBodyOn {
            let bodyResult = bodyService.stop()
            lastBody = bodyResult
            ev = ev.withBody(bodyResult)
        } else {
            lastBody = nil
        }
        store.add(ev)
        lastEvaluation = ev; showingResult = true; answeredCount += 1
        // v1.2 correct-me loop: ONE spoken script — answer correction +
        // body tips together (v1.1's second speak() cut the first one off).
        // Then, when the answer was wrong, ask the same question again so
        // he can answer it right away with the correction in mind.
        let shouldReask = store.autoReaskAfterCorrection && ev.overallScore < 80
        speech.speak(ev.spokenCorrection()) {
            if shouldReask {
                speech.speak("Try again. \(q.question)")
            }
        }
    }
    private func nextQuestion() {
        speech.stopSpeaking()
        if bodyService.isObserving { _ = bodyService.stop() }
        showingResult = false; lastEvaluation = nil; lastBody = nil
        speech.liveTranscript = ""
        if store.mode == .mock, answeredCount >= 5 { endSession(); return }
        if index + 1 < queue.count { index += 1 } else { rebuildQueue(); index = 0 }
        if let q = current { speech.speak("Next question. \(q.question)") }
    }
    private func retrySameQuestion() {
        speech.stopSpeaking(); showingResult = false; lastEvaluation = nil; lastBody = nil; speech.liveTranscript = ""
        if let q = current { speech.speak(q.question) }
    }
    private func endSession() {
        speech.stopSpeaking(); speech.stopListening()
        if bodyService.isObserving { _ = bodyService.stop() }
        started = false; showingResult = false; lastEvaluation = nil; lastBody = nil
        speech.liveTranscript = ""
        rebuildQueue()
    }
}

struct ScoreRing: View {
    let label: String; let score: Int; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 6).frame(width: 64, height: 64)
                Circle().trim(from: 0, to: CGFloat(score) / 100).stroke(color, lineWidth: 6).frame(width: 64, height: 64).rotationEffect(.degrees(-90))
                Text("\(score)").font(.headline)
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}
