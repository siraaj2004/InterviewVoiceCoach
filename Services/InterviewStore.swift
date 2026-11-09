import Foundation
import Combine

/// Session state + history. Everything is on-device (UserDefaults).
final class InterviewStore: ObservableObject {
    @Published var history: [Evaluation] = []
    @Published var selectedTopic: Topic = .all
    @Published var mode: InterviewMode = .practice
    @Published var speechRate: Double = 0.48
    @Published var selectedVoiceId: String?
    @Published var showIdealBeforeAnswer = false
    // v1.2: after a wrong answer is corrected by voice, ask the same
    // question again so he can try it right away. Saved on the phone.
    @Published var autoReaskAfterCorrection = true {
        didSet { UserDefaults.standard.set(autoReaskAfterCorrection, forKey: autoReaskKey) }
    }

    private let key = "ai-interview-voice-coach.history.v1"
    private let autoReaskKey = "ai-interview-voice-coach.autoReask.v1"

    init() {
        if let saved = UserDefaults.standard.object(forKey: autoReaskKey) as? Bool {
            autoReaskAfterCorrection = saved
        }
        load()
    }

    var totalAnswered: Int { history.count }
    var averageOverall: Int {
        guard !history.isEmpty else { return 0 }
        return history.map(\.overallScore).reduce(0, +) / history.count
    }
    var averageEnglish: Int {
        guard !history.isEmpty else { return 0 }
        return history.map(\.englishScore).reduce(0, +) / history.count
    }
    var averageContent: Int {
        guard !history.isEmpty else { return 0 }
        return history.map(\.contentScore).reduce(0, +) / history.count
    }
    var bestTopic: String {
        guard !history.isEmpty else { return "—" }
        var sums: [String: (total: Int, n: Int)] = [:]
        for h in history { sums[h.topic, default: (0, 0)].total += h.overallScore; sums[h.topic]!.n += 1 }
        return sums.max(by: { Double($0.value.total) / Double($0.value.n) < Double($1.value.total) / Double($1.value.n) })?.key ?? "—"
    }
    var weakestTopic: String {
        guard !history.isEmpty else { return "—" }
        var sums: [String: (total: Int, n: Int)] = [:]
        for h in history { sums[h.topic, default: (0, 0)].total += h.overallScore; sums[h.topic]!.n += 1 }
        return sums.min(by: { Double($0.value.total) / Double($0.value.n) < Double($1.value.total) / Double($1.value.n) })?.key ?? "—"
    }

    func add(_ evaluation: Evaluation) {
        history.insert(evaluation, at: 0)
        save()
    }
    func clearHistory() { history = []; save() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Evaluation].self, from: data) else { return }
        history = decoded
    }
    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
