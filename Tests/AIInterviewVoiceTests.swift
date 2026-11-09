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
}
