# AI Interview Voice Coach — iOS

Real-time voice interview practice for AI Engineer jobs, on iPhone.

## What it does
1. **Interviewer speaks in a real human voice** — iOS on-device enhanced en-US voice (Samantha / Daniel when downloaded). Pick the voice and speed in Settings.
2. **You answer by speaking** — tap the mic, answer out loud. Your words appear live as text.
3. **Wrong / partial = voice correction** — tap Stop & Check, then the app speaks the correct answer + one English tip. If the score is below 80 it speaks the correction automatically.
4. **English accuracy check on every answer** — fillers (um / uh / like), repeated words, grammar slips (he don't → he doesn't), pace in words/min, answer length. Plus a content score for missing key ideas.
5. **59 questions, 10 topics** — Python, SQL, Maths for AI, ML, Deep Learning, GenAI, AI Agents, MLOps, Coding, HR. Same bank as the daily interview practice.
6. **Modes** — Practice (one by one, shuffled) and Mock Interview (5 random questions).
7. **History** — overall / content / English averages, strongest and weakest topic, every answer with its correction to replay.
8. **Video body observation (v1.1)** — the front camera watches while you answer: posture (upright / slouched), eyes (looking at camera / away), movement (calm / fidgety), and how much of the answer you were visible. A Body score /100 with tips appears in the result card, in History, and as a spoken tip when it is below 70. A standalone Video tab lets you check body language on its own. On-device Vision only — no video is recorded, saved or uploaded. If the camera cannot see you, it says so instead of giving a fake score. It cannot judge confidence or answer quality, only what the camera sees.

No account, no server, no upload. Microphone + Speech Recognition are used only while you answer, camera only while the video check is on. History stays on the phone.

## Most human voice
iPhone Settings → Accessibility → Spoken Content → Voices → English (US) → download an **Enhanced** voice. Then in the app: Settings → Voice → pick it.

## Install on iPhone (unsigned IPA)
1. Push this repo to GitHub (public repo, e.g. `siraaj2004/AIInterviewVoice`).
2. GitHub → Actions → "AI Interview Voice tests and unsigned IPA" → Run workflow.
3. Download the `AIInterviewVoice-unsigned-ipa` artifact (14 days).
4. On Windows, install with **Sideloadly** or **AltStore** using your Apple ID — it signs the app for your phone. Free Apple ID: app expires in 7 days, reinstall to renew.
5. On iPhone, first open: allow Microphone + Speech Recognition when asked. If the app won't open, Settings → General → VPN & Device Management → trust your Apple ID.

## Build locally (Mac + Xcode)
```bash
brew install xcodegen
xcodegen generate
# open AIInterviewVoice.xcodeproj in Xcode, or:
bash scripts/package-unsigned-ipa.sh
```

## Tech
SwiftUI, iOS 16+, `AVSpeechSynthesizer` (TTS), `SFSpeechRecognizer` + `AVAudioEngine` (STT), on-device keyword + English-heuristics evaluation in `Services/EvaluationEngine.swift`, front camera + Vision human-body pose in `Services/BodyLanguageService.swift`. Tests in `Tests/` — 59-question bank check + scoring checks + body-result checks (10 tests).

## Versions
- v1.0.0 build 2 — voice interviewer, spoken answers, voice correction, English check. Run #1 failed on iOS 17-only `AVAudioApplication` (fixed to `AVAudioSession` in build 2); run #2 succeeded.
- v1.1.0 build 5 — adds video body observation. Runs #3/#4 failed (SwiftUI `body` name collision; Vision has no `.head` joint — use `.nose`); run #5 succeeded, 10 tests.
- v1.2.0 build 6 — correct-me loop (this version): live body correction banner while answering (on screen only — speaking live would be heard by the mic), one combined spoken correction (answer + body, fixing v1.1's double-speak cut-off), and the same question asked again after a wrong answer (toggle in Settings, on by default).

## Limits, stated plainly
- Swift is **not compiled on Linux** — the IPA is only real after the GitHub Actions run succeeds and its contents are verified. No IPA is claimed before that.
- Speech recognition needs internet for Apple's server recognition in some cases; TTS voices work offline once downloaded.
- English scoring is on-device heuristics (fillers, grammar patterns, pace), not a human examiner — treat it as a coach, not a certificate.
