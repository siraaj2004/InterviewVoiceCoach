# AI Interview Voice Coach — iOS

Real-time voice interview practice for AI Engineer jobs, on iPhone.

## What it does
1. **Interviewer speaks in a real human voice** — iOS on-device enhanced en-US voice (Samantha / Daniel when downloaded). Pick the voice and speed in Settings.
2. **You answer by speaking** — tap the mic, answer out loud. Your words appear live as text.
3. **Wrong / partial = voice correction + answer on screen** — tap Stop & Check, then the app speaks the correct answer + one English tip, and shows your answer, your scores and the correct answer on the same full-screen screen. Tap "Show answer" any time to read the ideal answer under the question. If the score is below 80 it speaks the correction automatically.
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
SwiftUI, iOS 16+, `AVSpeechSynthesizer` (TTS), `SFSpeechRecognizer` + `AVAudioEngine` (STT), on-device keyword + English-heuristics evaluation in `Services/EvaluationEngine.swift`, front camera + Vision human-body pose in `Services/BodyLanguageService.swift`. Tests in `Tests/` — 59-question bank check + scoring checks + body-result checks + correct-me-loop checks + camera switch checks + frozen-video fix checks + v1.6 full-release + gradient-correction checks + v1.7 on-screen-answer checks (22 tests).

## Versions
- v1.0.0 build 2 — voice interviewer, spoken answers, voice correction, English check. Run #1 failed on iOS 17-only `AVAudioApplication` (fixed to `AVAudioSession` in build 2); run #2 succeeded.
- v1.1.0 build 5 — adds video body observation. Runs #3/#4 failed (SwiftUI `body` name collision; Vision has no `.head` joint — use `.nose`); run #5 succeeded, 10 tests.
- v1.2.0 build 6 — correct-me loop: live body correction banner while answering (on screen only — speaking live would be heard by the mic), one combined spoken correction (answer + body, fixing v1.1's double-speak cut-off), and the same question asked again after a wrong answer (toggle in Settings, on by default). Phone-proven 2026-11-09: Video tab badges + 33/100 + tips all showed on shaik's iPhone — but the camera preview was black (2/136 frames with a person visible), so v1.3 fixes it.
- v1.3.0 build 7 — camera preview fix + front/back switch: the preview layer is now the view's own layer so the camera is actually visible; a "Switch camera" button (front ↔ back, mirrored preview for the front camera) in the Video tab and in the Interview answer card; a plain red message when the camera is off or unavailable instead of a black screen; the workflow test step now tries the iPhone 17 simulator first (run #6 ran 0 tests — the runner has no iPhone 16/15). Phone-proven 2026-11-09: shaik's screenshot shows the front camera live with him in frame, badges + "Switch camera" button visible.
- v1.4.0 build 8 — full-screen camera: the Video tab camera now fills the whole screen, front or back (Switch button in the bottom panel), with the live badges on top and the controls + result in a translucent bottom panel; observation starts as soon as you open the tab, so you see yourself straight away, and stops when you leave it. The Interview answer card still had its small 170pt preview then — v1.6 makes it full-screen too. Phone-proven 2026-11-09: shaik's video shows full-screen working, 60/100 with 42% visible — but the video froze after Stop + Start again, with a false "Camera not available" error.
- v1.5.0 build 9 (this version) — frozen-video fix: the session kept its old camera input after stopping, so starting again tried to attach the same camera twice and failed, leaving the preview frozen on the last frame. start() now drops any stale input first and reports honestly whether the camera is really running; the Video tab's buttons read their state from the service instead of a local flag, so they can never say "Stop" while the video is stuck.
- v1.6.0 build 10 — fixes the "Camera not available" error coming back on shaik's phone (Interview tab, Q3 #19 gradient, 2026-11-10 4:28 PM, while listening): stop() now fully releases the camera (inputs AND outputs removed, delegate cleared), start() builds a fresh video output every time, refuses to reconfigure a running session, and falls back to another camera only when the front one does not exist on the device — a busy camera now says so with a Retry camera button. The Interview camera is now full-screen like the Video tab (it was a 170pt box). The correct-me loop now speaks through the loudspeaker (it was routed to the quiet earpiece), re-asks the same question after a wrong answer, and starts the mic by itself for the retry; an unheard answer now says "I didn't hear you" instead of failing silently. Tests: 20.
- v1.7.0 build 11 (this version) — the answer now SHOWS ON SCREEN, not just by voice (shaik's screenshot, Q7 generator, 2026-11-11 9:07 PM): a "Show answer" button on the full-screen question card shows the ideal answer + tip in a green box under the question (same button on the plain question card when the video check is off; the Settings "show ideal before I answer" toggle still shows it by default). After Stop & Check the result — your spoken answer, scores, missing ideas, English tips and the correct answer — stays on the same full-screen camera screen instead of dropping into a scroll view where the correct answer sat below the fold; the camera restarts behind the result panel. The auto-retry now hides the result and restarts the mic on that same screen, so the retry transcript is visible while speaking. Tests: 22.

## Limits, stated plainly
- Swift is **not compiled on Linux** — the IPA is only real after the GitHub Actions run succeeds and its contents are verified. No IPA is claimed before that.
- Speech recognition needs internet for Apple's server recognition in some cases; TTS voices work offline once downloaded.
- English scoring is on-device heuristics (fillers, grammar patterns, pace), not a human examiner — treat it as a coach, not a certificate.
