import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: InterviewStore
    @EnvironmentObject private var speech: SpeechService

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            InterviewView()
                .tabItem { Label("Interview", systemImage: "mic.fill") }
            VideoInterviewView()
                .tabItem { Label("Video", systemImage: "video.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: InterviewStore
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Interview Voice Coach")
                            .font(.largeTitle.bold())
                        Text("Real interviewer voice. You answer by speaking. Wrong answers get corrected by voice, then the question is asked again — and every answer gets an English score, plus a body-language score from the front camera.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Answered", value: "\(store.totalAnswered)")
                        StatCard(title: "Avg score", value: store.totalAnswered == 0 ? "—" : "\(store.averageOverall)/100")
                        StatCard(title: "Avg English", value: store.totalAnswered == 0 ? "—" : "\(store.averageEnglish)/100")
                        StatCard(title: "Avg content", value: store.totalAnswered == 0 ? "—" : "\(store.averageContent)/100")
                    }
                    if store.totalAnswered > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Strongest: \(store.bestTopic)").font(.subheadline)
                            Text("Work on: \(store.weakestTopic)").font(.subheadline).foregroundColor(.orange)
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground)).cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How it works").font(.headline)
                        HowRow(n: "1", text: "Pick a topic, tap Interview. The app asks the question out loud in a human voice.")
                        HowRow(n: "2", text: "Tap the mic and answer by speaking. Your words appear live as text.")
                        HowRow(n: "3", text: "Tap Stop & Check. You get a content score + an English score (fillers, grammar, pace).")
                        HowRow(n: "4", text: "If it is wrong or partial, tap Hear correction — the app speaks the correct answer and one English tip. The answer also shows on screen.")
                        HowRow(n: "5", text: "Interview Prep mode asks the classic HR questions first — tell me about yourself, why hire you, five years — with the answer on screen to read and practise.")
                    }
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("63 questions • 10 topics").font(.headline)
                        Text("Python • SQL • Maths • ML • Deep Learning • GenAI • AI Agents • MLOps • Coding • HR — the same bank as your daily interview practice.")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text("Tip: for the most human voice, download an enhanced voice in Settings → Accessibility → Spoken Content → Voices → English (US).")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Voice Interview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatCard: View {
    let title: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2.bold())
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground)).cornerRadius(12)
    }
}

struct HowRow: View {
    let n: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.headline).frame(width: 26, height: 26).background(Color.blue).foregroundColor(.white).clipShape(Circle())
            Text(text).font(.subheadline)
        }
    }
}
