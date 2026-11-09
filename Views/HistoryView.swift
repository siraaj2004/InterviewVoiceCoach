import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: InterviewStore
    @EnvironmentObject private var speech: SpeechService
    var body: some View {
        NavigationView {
            Group {
                if store.history.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "mic.slash").font(.largeTitle).foregroundColor(.secondary)
                        Text("No answers yet").font(.headline)
                        Text("Do your first voice interview — your scores, English tips and corrections will appear here.").foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    List {
                        Section("Summary") {
                            Text("Answered: \(store.totalAnswered)  •  Avg overall \(store.averageOverall)/100  •  Avg English \(store.averageEnglish)/100")
                            Text("Strongest: \(store.bestTopic)  •  Work on: \(store.weakestTopic)")
                        }
                        Section("Recent answers") {
                            ForEach(store.history) { ev in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(ev.topic).font(.caption.bold())
                                        Spacer()
                                        Text("\(ev.overallScore)/100").font(.caption.bold())
                                            .padding(4).background(scoreColor(ev.overallScore).opacity(0.15)).cornerRadius(6)
                                    }
                                    Text(ev.question).font(.subheadline.bold())
                                    Text("“\(ev.transcript)”").font(.subheadline).lineLimit(3)
                                    Text("\(ev.verdict) • English \(ev.englishScore)/100 • Content \(ev.contentScore)/100").font(.caption).foregroundColor(.secondary)
                                    Text(ev.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundColor(.secondary)
                                    HStack {
                                        Button("Hear correction") { speech.speak(ev.correctedAnswer) }.font(.caption)
                                        Button("Hear my answer") { speech.speak(ev.transcript) }.font(.caption)
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                        Section {
                            Button("Clear history", role: .destructive) { store.clearHistory() }
                        }
                    }
                }
            }
            .navigationTitle("History & Scores")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func scoreColor(_ s: Int) -> Color { s >= 80 ? .green : s >= 60 ? .orange : .red }
}
