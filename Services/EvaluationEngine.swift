import Foundation

/// On-device evaluation — no server, no AI key needed.
/// Content = did the spoken answer cover the question's key ideas?
/// English = fillers, repeats, grammar slips, pace, length, clarity.
struct EvaluationEngine {
    static let fillers = ["um", "uh", "hmm", "like", "you know", "basically", "actually", "literally", "so yeah", "kind of", "sort of"]
    // Common spoken-English slips to flag with a fix.
    static let grammarFixes: [(wrong: String, right: String, tip: String)] = [
        ("i is", "I am", "Say 'I am', not 'I is'."),
        ("he don't", "he doesn't", "Say 'he doesn't', not 'he don't'."),
        ("she don't", "she doesn't", "Say 'she doesn't', not 'she don't'."),
        ("they is", "they are", "Say 'they are', not 'they is'."),
        ("i has", "I have", "Say 'I have', not 'I has'."),
        ("me and him", "he and I", "Say 'he and I', not 'me and him'."),
        ("didn't went", "didn't go", "After 'didn't', use 'go', not 'went'."),
        ("more better", "better", "Say 'better', not 'more better'."),
        ("i am having", "I have", "Say 'I have', not 'I am having', for possession."),
        ("yesterday i go", "yesterday I went", "Yesterday needs past tense: 'went'."),
    ]

    static func evaluate(question: InterviewQuestion, transcript: String, durationSeconds: Double) -> Evaluation {
        let lower = " " + transcript.lowercased() + " "
        let words = transcript.split(separator: " ").map(String.init)
        let wordCount = words.count

        // --- Content score: keyword coverage ---
        var missing: [String] = []
        var hit = 0
        for kw in question.keywords {
            if lower.contains(kw.lowercased()) { hit += 1 } else { missing.append(kw) }
        }
        let coverage = question.keywords.isEmpty ? 0 : Double(hit) / Double(question.keywords.count)
        var content = Int(round(coverage * 75))
        if wordCount >= 20 { content += 15 }
        else if wordCount >= 10 { content += 8 }
        if wordCount < 5 { content = min(content, 25) }
        content = max(0, min(100, content))

        // --- English score ---
        var english = 100
        var tips: [String] = []
        var fillerCount = 0
        for f in fillers {
            let n = lower.components(separatedBy: f).count - 1
            fillerCount += max(0, n)
        }
        if fillerCount > 0 {
            english -= min(20, fillerCount * 4)
            tips.append("You used \(fillerCount) filler word\(fillerCount == 1 ? "" : "s") (um, uh, like). Pause silently instead — it sounds more confident.")
        }
        // Repeated word (stammer): same word 3+ times in a row.
        var repeats = 0
        for i in 2..<words.count where words[i].lowercased() == words[i-1].lowercased() && words[i].lowercased() == words[i-2].lowercased() { repeats += 1 }
        if repeats > 0 { english -= 5; tips.append("You repeated a word while thinking. Slow down and pause instead of repeating.") }
        // Double word (I I, the the)
        var doubles = 0
        for i in 1..<words.count where words[i].lowercased() == words[i-1].lowercased() { doubles += 1 }
        if doubles > 0 { english -= min(10, doubles * 3); tips.append("Watch doubled words like '\(words.first ?? "") \(words.first ?? "")'. Speak a little slower.") }
        // Grammar slips
        for fix in grammarFixes where lower.contains(fix.wrong) {
            english -= 8; tips.append(fix.tip)
        }
        // Pace
        let minutes = max(durationSeconds / 60, 0.05)
        let wpm = Int(round(Double(wordCount) / minutes))
        if durationSeconds > 3 {
            if wpm < 70 { english -= 8; tips.append("You spoke quite slowly (\(wpm) words/min). Aim for about 110–140 words/min — interview pace.") }
            else if wpm > 180 { english -= 8; tips.append("You spoke very fast (\(wpm) words/min). Slow to about 110–140 words/min so the interviewer can follow.") }
        }
        if wordCount < 10 { english -= 15; tips.append("Your answer was very short (\(wordCount) words). Aim for 2–3 sentences with one example.") }
        if wordCount > 120 { english -= 5; tips.append("Long answer — keep it to 3–4 sentences in an interview.") }
        // Sentence shape: no verb at all is a fragment.
        let verbs = ["is", "are", "was", "were", "has", "have", "can", "use", "uses", "means", "lets", "does", "do", "takes", "gives", "works"]
        if !words.isEmpty && !words.contains(where: { verbs.contains($0.lowercased()) }) {
            english -= 5; tips.append("Add a main verb — e.g. 'It means…' or 'It uses…' — so the sentence is complete.")
        }
        if tips.isEmpty { tips.append("Clear English — good pace, no fillers. Keep this style.") }
        english = max(0, min(100, english))

        let overall = (content * 6 + english * 4) / 10
        let verdict: String
        switch overall { case 80...100: verdict = "Correct — well answered"
        case 60..<80: verdict = "Partly correct — close, polish the missing points"
        case 40..<60: verdict = "Needs correction — listen to the correct answer"
        default: verdict = "Incorrect / too short — listen and try again" }

        // Voice correction script: spoken back to the user.
        let corrected = "The correct answer is: \(question.idealAnswer) \(question.tip)"
        return Evaluation(
            id: UUID(), questionId: question.id, question: question.question, topic: question.topic.rawValue,
            transcript: transcript, date: Date(), durationSeconds: durationSeconds,
            contentScore: content, englishScore: english, overallScore: overall, verdict: verdict,
            missingKeywords: missing, fillerCount: fillerCount, wordsPerMinute: wpm,
            englishTips: tips, correctedAnswer: corrected
        )
    }
}
