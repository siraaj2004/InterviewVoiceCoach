import XCTest
@testable import AIInterviewVoice

final class AIInterviewVoiceTests: XCTestCase {
    func testBankHas59Questions() {
        XCTAssertEqual(QuestionBank.all.count, 59)
        XCTAssertEqual(Set(QuestionBank.all.map(\.id)).count, 59)
    }
    func testBankCovers10Topics() {
        let topics = Set(QuestionBank.all.map(\.topic))
        XCTAssertEqual(topics.count, 10)
    }
    func testEveryQuestionHasKeywordsAndIdealAnswer() {
        for q in QuestionBank.all {
            XCTAssertFalse(q.question.isEmpty, "Q\(q.id) empty")
            XCTAssertFalse(q.keywords.isEmpty, "Q\(q.id) no keywords")
            XCTAssertFalse(q.idealAnswer.isEmpty, "Q\(q.id) no ideal answer")
        }
    }
    func testGoodAnswerScoresHigh() {
        let q = QuestionBank.all[0] // variable
        let ev = EvaluationEngine.evaluate(question: q, transcript: "A variable is a named reference to a value stored in memory. When I write x equals 10, the name x is bound to the integer object 10.", durationSeconds: 12)
        XCTAssertGreaterThanOrEqual(ev.contentScore, 70)
        XCTAssertGreaterThanOrEqual(ev.overallScore, 60)
    }
    func testWrongShortAnswerScoresLowAndListsMissingKeywords() {
        let q = QuestionBank.all[0]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "I don't know.", durationSeconds: 3)
        XCTAssertLessThan(ev.contentScore, 40)
        XCTAssertFalse(ev.missingKeywords.isEmpty)
        XCTAssertFalse(ev.correctedAnswer.isEmpty)
    }
    func testFillerWordsLowerEnglishScore() {
        let q = QuestionBank.all[20] // ML
        let clean = EvaluationEngine.evaluate(question: q, transcript: "Machine learning lets computers learn patterns from data and make predictions on new data.", durationSeconds: 10)
        let fillers = EvaluationEngine.evaluate(question: q, transcript: "Um machine learning uh like lets computers um learn patterns from data uh and make predictions on new data.", durationSeconds: 12)
        XCTAssertLessThan(fillers.englishScore, clean.englishScore)
        XCTAssertGreaterThan(fillers.fillerCount, 0)
    }
    func testGrammarSlipIsFlagged() {
        let q = QuestionBank.all[20]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "He don't learn patterns from data, machine learning is good.", durationSeconds: 8)
        XCTAssertTrue(ev.englishTips.contains(where: { $0.contains("doesn't") }))
    }
    // v1.1 body observation — no camera needed for these.
    func testEvaluationStartsWithNoBodyScore() {
        let q = QuestionBank.all[0]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "A variable is a named reference to a value stored in memory.", durationSeconds: 10)
        XCTAssertNil(ev.bodyScore)
        XCTAssertNil(ev.bodyTips)
    }
    func testWithBodyAttachesBodyResult() {
        let q = QuestionBank.all[0]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "A variable is a named reference to a value stored in memory.", durationSeconds: 10)
        let body = BodyLanguageResult(bodyScore: 82, postureLabel: "Upright", eyeLabel: "Looking at camera", movementLabel: "Calm", personVisiblePercent: 100, tips: ["Keep your posture upright."])
        let withBody = ev.withBody(body)
        XCTAssertEqual(withBody.bodyScore, 82)
        XCTAssertEqual(withBody.bodyPosture, "Upright")
        XCTAssertEqual(withBody.bodyEye, "Looking at camera")
        XCTAssertEqual(withBody.bodyTips?.first, "Keep your posture upright.")
    }
    func testBodyResultDefaultsToCannotTell() {
        let body = BodyLanguageResult()
        XCTAssertEqual(body.bodyScore, 0)
        XCTAssertEqual(body.postureLabel, "Not checked")
        XCTAssertEqual(body.personVisiblePercent, 0)
        XCTAssertTrue(body.tips.isEmpty)
    }
    // v1.2 correct-me loop — one spoken script, answer + body together.
    func testSpokenCorrectionCombinesAnswerAndBody() {
        let q = QuestionBank.all[0]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "I don't know.", durationSeconds: 3)
        let body = BodyLanguageResult(bodyScore: 50, postureLabel: "Slouched — sit upright", eyeLabel: "Looking away a lot", movementLabel: "Calm — good", personVisiblePercent: 90, tips: ["Sit upright — shoulders back, head level."])
        let script = ev.withBody(body).spokenCorrection()
        XCTAssertTrue(script.contains("The correct answer is"))
        XCTAssertTrue(script.contains("Body language:"))
        XCTAssertTrue(script.contains("Sit upright"))
    }
    func testSpokenCorrectionForGoodAnswerHasNoCorrection() {
        let q = QuestionBank.all[0]
        let ev = EvaluationEngine.evaluate(question: q, transcript: "A variable is a named reference to a value stored in memory. When I write x equals 10, the name x is bound to the integer object 10.", durationSeconds: 12)
        XCTAssertTrue(ev.spokenCorrection().hasPrefix("Good answer."))
        XCTAssertFalse(ev.spokenCorrection().contains("The correct answer is"))
    }
    func testAutoReaskDefaultsOn() {
        // Fresh store (no saved setting in the test runner) must re-ask
        // after a correction by default.
        UserDefaults.standard.removeObject(forKey: "ai-interview-voice-coach.autoReask.v1")
        let store = InterviewStore()
        XCTAssertTrue(store.autoReaskAfterCorrection)
    }
    // v1.3 camera — no hardware needed for these.
    // BodyLanguageService is @MainActor, so these tests must be too —
    // run #7's test bundle failed to compile without this.
    @MainActor
    func testDefaultCameraIsFront() {
        let service = BodyLanguageService()
        XCTAssertEqual(service.cameraPosition, .front)
        XCTAssertNil(service.cameraError)
        XCTAssertFalse(service.isObserving)
    }
    @MainActor
    func testSwitchCameraTogglesPosition() {
        let service = BodyLanguageService()
        service.switchCamera()
        XCTAssertEqual(service.cameraPosition, .back)
        service.switchCamera()
        XCTAssertEqual(service.cameraPosition, .front)
    }
    // v1.5 frozen-video fix — on the simulator there is no camera, so
    // start() must fail honestly instead of claiming it is observing.
    // cameraError is NOT asserted here: on a fresh simulator the permission
    // status is .notDetermined, so start() returns false while the
    // permission request is still in flight and the error is set later by
    // the callback. The synchronous contract — false return, never
    // claiming to observe — is what the app relies on.
    @MainActor
    func testStartReturnsFalseWithoutCamera() {
        let service = BodyLanguageService()
        XCTAssertFalse(service.start())
        XCTAssertFalse(service.isObserving)
    }
    @MainActor
    func testSecondStartDoesNotClaimSuccess() {
        let service = BodyLanguageService()
        XCTAssertFalse(service.start())
        XCTAssertFalse(service.start())
        XCTAssertFalse(service.isObserving)
    }
    // v1.6 — stop() must FULLY release the camera (inputs AND outputs),
    // so the next start() is a clean start, not a stale-output failure.
    @MainActor
    func testStopReleasesCameraInputsAndOutputs() {
        let service = BodyLanguageService()
        XCTAssertFalse(service.start())
        let result = service.stop()
        XCTAssertFalse(service.isObserving)
        XCTAssertTrue(service.captureSession.inputs.isEmpty)
        XCTAssertTrue(service.captureSession.outputs.isEmpty)
        XCTAssertEqual(result.bodyScore, 0)
    }
    @MainActor
    func testStartAfterStopIsStillHonestWithoutCamera() {
        let service = BodyLanguageService()
        XCTAssertFalse(service.start())
        _ = service.stop()
        XCTAssertFalse(service.start())
        XCTAssertFalse(service.isObserving)
    }
    // v1.6 — the exact question in shaik's screenshot (Q19, gradient):
    // a wrong answer must score below 80 and its spoken correction must
    // carry the real correct answer, so the auto-retry fires.
    func testGradientWrongAnswerGetsCorrectionAndReask() {
        let q = QuestionBank.all[18] // Q19 gradient
        XCTAssertTrue(q.question.contains("gradient"))
        let ev = EvaluationEngine.evaluate(question: q, transcript: "I don't know.", durationSeconds: 3)
        XCTAssertLessThan(ev.overallScore, 80)
        XCTAssertTrue(ev.verdict.contains("Incorrect") || ev.verdict.contains("Needs correction"))
        let script = ev.spokenCorrection()
        XCTAssertTrue(script.contains("The correct answer is"))
        XCTAssertTrue(script.contains("steepest"))
        XCTAssertTrue(script.contains("opposite direction"))
    }
}
