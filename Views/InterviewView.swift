import SwiftUI

/// v1.7.0 — the answer now SHOWS ON SCREEN, not just by voice:
/// a "Show answer" button on the full-screen question card displays
/// the ideal answer + tip in a green box under the question, and after
/// Stop & Check the result (your spoken answer, scores, correct
/// answer) stays on the same full-screen camera screen instead of
/// dropping into a scroll view where the correct answer sat below the
/// fold. The auto-retry then hides the result and restarts the mic
/// on that same screen.
/// v1.6.0 — Interview tab camera is now FULL-SCREEN (it was a 170pt box),
/// the same full-screen pattern as the Video tab: the camera fills the
/// screen behind translucent question + answer panels, with the live
/// posture / eyes / movement badges on top. And the correct-me loop now
/// finishes the job: after a wrong answer the correction is spoken
/// through the loudspeaker, the same question is asked again, and the
/// mic starts by itself so he can answer the corrected question
/// straight away — no extra taps, and no silent failure when nothing
/// was heard.
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
    // v1.6: heard-nothing feedback + auto-retry state.
    @State private var heardNothing = false
    @State private var awaitingRetry = false
    // v1.7: "Show answer" on screen — ideal answer + tip under the
    // question, on the full-screen card and on the plain question card.
    @State private var showAnswer = false

    private var current: InterviewQuestion? { queue.isEmpty ? nil : queue[index] }
    /// v1.7: the ideal answer is visible whenever he asked for it, or
    /// whenever the Settings toggle says to show it before answering.
    private var answerVisible: Bool { showAnswer || store.showIdealBeforeAnswer }

    var body: some View {
        NavigationView {
            // v1.7: stay on the full-screen camera screen while
            // answering AND while the result is shown, so the answer
            // is on screen in both states. The scroll view is only
            // for setup (not started) or when the video check is off.
            if started, videoBodyOn, let q = current {
                fullScreenInterview(q)
            } else {
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
            }
        }
        .onChange(of: store.selectedTopic) { _ in if !started { rebuildQueue() } }
        .onAppear { if queue.isEmpty { rebuildQueue() } }
    }

    // MARK: Full-screen interview (v1.6, v1.7 result on screen)
    /// Camera fills the whole screen; question on top, answer controls
    /// in a translucent bottom panel. Used while answering AND while
    /// the result is shown (v1.7), so the correct answer is readable
    /// on the same screen instead of only spoken or buried in a scroll
    /// view. Once the auto-retry fires, the result hides and the mic
    /// restarts on this same screen.
    private func fullScreenInterview(_ q: InterviewQuestion) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if bodyService.isObserving {
                CameraPreview(session: bodyService.captureSession, mirrored: bodyService.cameraPosition == .front)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    BodyBadge(text: "Posture: \(bodyService.livePosture)", good: bodyService.livePosture == "Upright")
                    BodyBadge(text: "Eyes: \(bodyService.liveEye)", good: bodyService.liveEye == "Looking at camera")
                    BodyBadge(text: "Move: \(bodyService.liveMovement)", good: bodyService.liveMovement == "Calm")
                    Spacer()
                    Button { bodyService.switchCamera() } label: {
                        Label(bodyService.cameraPosition == .front ? "Front" : "Back", systemImage: "camera.rotate")
                    }.font(.caption.bold()).buttonStyle(.bordered).tint(.white)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(q.topic.rawValue).font(.caption.bold()).padding(6).background(Color.blue.opacity(0.85)).foregroundColor(.white).cornerRadius(8)
                        Text(q.difficulty.rawValue).font(.caption).padding(6).background(Color.green.opacity(0.85)).foregroundColor(.white).cornerRadius(8)
                        Spacer()
                        Text(questionCounter(for: q)).font(.caption).foregroundColor(.white.opacity(0.85))
                    }
                    Text(q.question).font(.title3.bold()).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Button { speech.speak(q.question) } label: {
                            Label(speech.isSpeaking ? "Speaking…" : "Hear question", systemImage: "speaker.wave.2.fill")
                        }.buttonStyle(.borderedProminent).disabled(speech.isSpeaking)
                        Button("Repeat") { speech.speak(q.question) }.buttonStyle(.bordered).tint(.white)
                        Button("Next") { nextQuestion() }.buttonStyle(.bordered).tint(.white)
                    }
                    // v1.7: Show answer on screen — the ideal answer +
                    // tip, in a green box right under the question.
                    Button { showAnswer.toggle() } label: {
                        Label(answerVisible ? "Hide answer" : "Show answer", systemImage: answerVisible ? "eye.slash.fill" : "eye.fill")
                    }.buttonStyle(.bordered).tint(.white)
                    if answerVisible {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Answer: \(q.idealAnswer)").font(.subheadline.bold()).foregroundColor(.white)
                            Text("Tip: \(q.tip)").font(.footnote).foregroundColor(.white.opacity(0.85))
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.55)).cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.55))
                .cornerRadius(14)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                Spacer()
                if let ev = lastEvaluation, showingResult {
                    fullScreenResultPanel(ev)
                } else {
                    fullScreenAnswerPanel(q)
                }
            }
        }
        .navigationTitle("Voice Interview")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Full-screen result (v1.7) — your answer + correct answer
    // on the same camera screen, right after Stop & Check.
    private func fullScreenResultPanel(_ ev: Evaluation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(ev.verdict).font(.headline).foregroundColor(.white)
                    Spacer()
                    Text("\(ev.overallScore)/100").font(.title3.bold()).foregroundColor(.white)
                }
                Text(ev.overallLabel).font(.subheadline).foregroundColor(.white.opacity(0.85))
                HStack(spacing: 12) {
                    ScoreRing(label: "Overall", score: ev.overallScore, color: .blue)
                    ScoreRing(label: "Content", score: ev.contentScore, color: .green)
                    ScoreRing(label: "English", score: ev.englishScore, color: .orange)
                    if let bs = ev.bodyScore {
                        ScoreRing(label: "Body", score: bs, color: .purple)
                    }
                }
                .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your answer (\(ev.transcript.split(separator: " ").count) words, \(ev.wordsPerMinute) words/min, \(ev.fillerCount) fillers)").font(.caption).foregroundColor(.white.opacity(0.85))
                    Text("“\(ev.transcript)”").font(.subheadline).italic().foregroundColor(.white)
                }
                if !ev.missingKeywords.isEmpty {
                    Text("Missing ideas: \(ev.missingKeywords.joined(separator: ", "))").font(.subheadline).foregroundColor(.orange)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Correct answer").font(.subheadline.bold()).foregroundColor(.white)
                    Text(ev.correctedAnswer).font(.subheadline).foregroundColor(.white)
                }
                if !ev.englishTips.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("English tips").font(.subheadline.bold()).foregroundColor(.white)
                        ForEach(ev.englishTips, id: \.self) { Text("• \($0)").font(.subheadline).foregroundColor(.white.opacity(0.9)) }
                    }
                }
                HStack(spacing: 10) {
                    Button { speech.speak(ev.correctedAnswer) } label: {
                        Label(speech.isSpeaking ? "Speaking…" : "Hear correction", systemImage: "speaker.wave.2.fill")
                    }.buttonStyle(.borderedProminent).disabled(speech.isSpeaking)
                    Button("Try again") { retrySameQuestion() }.buttonStyle(.bordered).tint(.white)
                    Button("Next question") { nextQuestion() }.buttonStyle(.bordered).tint(.white)
                }
                if awaitingRetry {
                    Text("Correction spoken — your turn: speak the corrected answer now.").font(.subheadline).foregroundColor(.green)
                }
                Button("End session") { endSession() }.font(.footnote).foregroundColor(.red)
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.55))
        .cornerRadius(18)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: Full-screen answer panel (v1.7) — the live answer box,
    // split out of fullScreenInterview so the result panel can
    // replace it after Stop & Check on the same screen.
    private func fullScreenAnswerPanel(_ q: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your answer — speak it").font(.headline).foregroundColor(.white)
            if videoBodyOn, let error = bodyService.cameraError {
                Text(error).font(.subheadline).foregroundColor(.red)
                Button("Retry camera") { _ = bodyService.start() }.buttonStyle(.borderedProminent)
            }
            if let banner = bodyCorrectionBanner {
                Text(banner).font(.subheadline.bold()).foregroundColor(.white)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.7)).cornerRadius(10)
            }
            if heardNothing {
                Text("I didn't hear you — tap the mic and try again.").font(.subheadline).foregroundColor(.orange)
            }
            if speech.isListening {
                Text(speech.liveTranscript.isEmpty ? "Listening… speak now" : speech.liveTranscript)
                    .font(.body).foregroundColor(.white).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.35)).cornerRadius(10)
            } else if !speech.liveTranscript.isEmpty {
                Text(speech.liveTranscript).font(.body).foregroundColor(.white).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.15)).cornerRadius(10)
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
                    Button("Stop voice") { speech.stopSpeaking() }.buttonStyle(.bordered).tint(.white)
                }
            }
            Text("Tip: answer in 2–3 full sentences. Avoid um / uh — pause silently instead.")
                .font(.footnote).foregroundColor(.white.opacity(0.85))
            Button("End session") { endSession() }.font(.footnote).foregroundColor(.red)
        }
        .padding(14)
        .background(Color.black.opacity(0.55))
        .cornerRadius(18)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
            Text("Front camera only, on this phone, full-screen while you answer. No video is recorded, saved or uploaded.")
                .font(.footnote).foregroundColor(.secondary)
            Text(setupSummary)
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
                Text(questionCounter(for: q)).font(.caption).foregroundColor(.secondary)
            }
            Text(q.question).font(.title3.bold())
            HStack(spacing: 10) {
                Button { speech.speak(q.question) } label: {
                    Label(speech.isSpeaking ? "Speaking…" : "Hear question", systemImage: "speaker.wave.2.fill")
                }.buttonStyle(.borderedProminent).disabled(speech.isSpeaking)
                Button("Repeat") { speech.speak(q.question) }.buttonStyle(.bordered)
                Button("Next") { nextQuestion() }.buttonStyle(.bordered)
            }
            // v1.7: Show answer on screen here too (video check off).
            Button { showAnswer.toggle() } label: {
                Label(answerVisible ? "Hide answer" : "Show answer", systemImage: answerVisible ? "eye.slash.fill" : "eye.fill")
            }.buttonStyle(.bordered)
            if answerVisible {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Answer: \(q.idealAnswer)").font(.subheadline.bold())
                    Text("Tip: \(q.tip)").font(.footnote).foregroundColor(.secondary)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.15)).cornerRadius(10)
            }
        }
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    // MARK: Answer
    private func answerCard(_ q: InterviewQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your answer — speak it").font(.headline)
            // v1.6: no small preview box here any more — while answering,
            // the camera is full-screen (see fullScreenInterview). This
            // card only shows the live status while the result is on screen.
            if videoBodyOn && bodyService.isObserving {
                HStack(spacing: 8) {
                    Text("Posture: \(bodyService.livePosture)").font(.caption.bold())
                    Text("Eyes: \(bodyService.liveEye)").font(.caption.bold())
                    Text("Move: \(bodyService.liveMovement)").font(.caption.bold())
                    Button { bodyService.switchCamera() } label: {
                        Label(bodyService.cameraPosition == .front ? "Front" : "Back", systemImage: "camera.rotate")
                    }.font(.caption).buttonStyle(.bordered)
                }
                Text(bodyService.personVisible ? "Camera can see you — keep head and shoulders in frame." : "Camera cannot see you yet — sit in frame, good light on your face.")
                    .font(.caption).foregroundColor(.secondary)
                if let banner = bodyCorrectionBanner {
                    Text(banner).font(.subheadline.bold())
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2)).cornerRadius(10)
                }
            }
            if videoBodyOn, let error = bodyService.cameraError {
                Text(error).font(.subheadline).foregroundColor(.red)
                Button("Retry camera") { _ = bodyService.start() }.buttonStyle(.borderedProminent)
            }
            if heardNothing {
                Text("I didn't hear you — tap the mic and try again.").font(.subheadline).foregroundColor(.orange)
            }
            if awaitingRetry {
                Text("Correction spoken — your turn: speak the corrected answer now.").font(.subheadline).foregroundColor(.green)
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
        // v1.7 Interview Prep: a full AI Engineer interview — the 9
        // classic HR questions first (shuffled), then the whole
        // technical bank (shuffled). Practice/Mock keep the old order.
        if store.mode == .prep {
            let hr = QuestionBank.all.filter { $0.topic == .hr }.shuffled()
            let technical = QuestionBank.all.filter { $0.topic != .hr }.shuffled()
            queue = hr + technical
        } else {
            queue = QuestionBank.questions(for: store.selectedTopic).shuffled()
        }
        index = 0
    }
    /// v1.7: Mock shows Q n / 5, Interview Prep shows Q n / 63,
    /// Practice shows the question's bank number.
    private func questionCounter(for q: InterviewQuestion) -> String {
        if store.mode == .mock { return "Q \(index + 1) / 5" }
        if store.mode == .prep { return "Q \(index + 1) / \(queue.count)" }
        return "Q \(index + 1) • #\(q.id)"
    }
    private var setupSummary: String {
        if store.mode == .prep {
            return "Interview Prep: a full AI Engineer interview — 9 classic HR questions first, then Python, ML, GenAI, Agents and more. 63 questions. Answer by speaking, and read the answer on screen."
        }
        return "\(QuestionBank.questions(for: store.selectedTopic).count) questions in this topic • \(store.mode == .mock ? "Mock: 5 random questions" : "Practice: go one by one, shuffled")"
    }
    private func startSession() {
        rebuildQueue()
        if store.mode == .mock { queue = Array(queue.prefix(5)) }
        started = true; answeredCount = 0; lastEvaluation = nil; showingResult = false
        heardNothing = false; awaitingRetry = false
        showAnswer = store.showIdealBeforeAnswer
        speech.speechRate = Float(store.speechRate)
        speech.voiceIdentifier = store.selectedVoiceId
        if let q = current { speech.speak("Question \(index + 1). \(q.question)") }
    }
    private func startListening() {
        heardNothing = false
        speech.speechRate = Float(store.speechRate)
        speech.voiceIdentifier = store.selectedVoiceId
        if videoBodyOn { bodyService.start() }
        speech.startListening { _, _ in }
    }
    private func finishAnswer(for q: InterviewQuestion) {
        let text = speech.liveTranscript
        speech.stopListening()
        // v1.6: never fail silently on an unheard answer — the old code
        // just returned, so a quiet answer looked like the app did nothing
        // and no correction ever came.
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            heardNothing = true
            speech.speak("I didn't hear you. Tap the mic and try again.")
            return
        }
        heardNothing = false
        // Real measured listen duration from SpeechService; fall back to a
        // 130 wpm pace estimate only if the measurement is missing.
        let duration = speech.lastListenDuration > 0 ? speech.lastListenDuration : Double(text.split(separator: " ").count) / 130 * 60
        var ev = EvaluationEngine.evaluate(question: q, transcript: text, durationSeconds: duration)
        // v1.1: stop the camera observation and attach the body result.
        if videoBodyOn {
            let bodyResult = bodyService.stop()
            lastBody = bodyResult
            ev = ev.withBody(bodyResult)
            // v1.7: the result now shows on the same full-screen camera
            // screen, so restart the camera behind the result panel —
            // the body result is already captured, new frames cannot
            // change it. startListening() on retry is a no-op if the
            // session is already running (v1.6 guard).
            _ = bodyService.start()
        } else {
            lastBody = nil
        }
        store.add(ev)
        lastEvaluation = ev; showingResult = true; answeredCount += 1
        // v1.2 correct-me loop, v1.6 auto-retry: ONE spoken script —
        // answer correction + body tips together — then, when the answer
        // was wrong, the same question is asked again AND the mic starts
        // by itself, so he can answer the corrected question straight
        // away. The guards stop a stale retry if he already tapped Next,
        // Try again, or End session while the correction was speaking.
        let shouldReask = store.autoReaskAfterCorrection && ev.overallScore < 80
        awaitingRetry = shouldReask
        speech.speak(ev.spokenCorrection()) {
            guard shouldReask, self.started, self.current?.id == q.id, self.showingResult else { return }
            self.speech.speak("Try again. \(q.question)") {
                guard self.started, self.current?.id == q.id, self.showingResult else { return }
                // v1.7: hide the result and go back to the answer box
                // on the same full-screen screen before the mic starts,
                // so the retry transcript is visible while speaking.
                self.awaitingRetry = false
                self.showingResult = false
                self.lastEvaluation = nil
                self.lastBody = nil
                self.speech.liveTranscript = ""
                self.showAnswer = self.store.showIdealBeforeAnswer
                self.startListening()
            }
        }
    }
    private func nextQuestion() {
        speech.stopSpeaking()
        awaitingRetry = false; heardNothing = false
        showAnswer = store.showIdealBeforeAnswer
        if bodyService.isObserving { _ = bodyService.stop() }
        showingResult = false; lastEvaluation = nil; lastBody = nil
        speech.liveTranscript = ""
        if store.mode == .mock, answeredCount >= 5 { endSession(); return }
        if index + 1 < queue.count { index += 1 } else { rebuildQueue(); index = 0 }
        if let q = current { speech.speak("Next question. \(q.question)") }
    }
    private func retrySameQuestion() {
        speech.stopSpeaking(); showingResult = false; lastEvaluation = nil; lastBody = nil; speech.liveTranscript = ""
        awaitingRetry = false; heardNothing = false
        showAnswer = store.showIdealBeforeAnswer
        if let q = current { speech.speak(q.question) }
    }
    private func endSession() {
        speech.stopSpeaking(); speech.stopListening()
        awaitingRetry = false; heardNothing = false
        showAnswer = false
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
