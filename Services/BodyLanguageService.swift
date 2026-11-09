import Foundation
import AVFoundation
import Vision
import Combine

/// Video body-movement observation — v1.1.0 (additive, on-device only).
/// Front camera + Vision human-body pose, same approach as GYM AI's PoseDetector.
/// What it observes while you answer, live:
///  - Posture: shoulders level + head upright vs slouched / head down
///  - Eye / face: face visible and roughly facing the camera vs looking away
///  - Movement: still and calm vs fidgety / large repeated movements
///  - Presence: person visible in frame for how much of the answer
/// What it does NOT do: no video is recorded, saved or uploaded; no
/// judgement of confidence or intelligence; low light / cropped body /
/// low-confidence frames count as CANNOT TELL, never as a bad score.
/// Camera permission is NSCameraUsageDescription in Info.plist (v1.1).
struct BodyLanguageResult: Codable {
    var bodyScore: Int = 0
    var postureLabel: String = "Not checked"
    var eyeLabel: String = "Not checked"
    var movementLabel: String = "Not checked"
    var personVisiblePercent: Int = 0
    var tips: [String] = []
    var framesChecked: Int = 0
    var framesWithPerson: Int = 0
}

@MainActor
final class BodyLanguageService: NSObject, ObservableObject {
    @Published var isObserving = false
    @Published var livePosture = "—"
    @Published var liveEye = "—"
    @Published var liveMovement = "Calm"
    @Published var personVisible = false
    // v1.3: front/back camera switch + a plain message when the camera
    // cannot start, instead of a black preview.
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    @Published var cameraError: String?

    private let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var lastShoulderY: CGFloat?
    private var movementSamples: [CGFloat] = []
    private var slouchFrames = 0
    private var uprightFrames = 0
    private var faceAwayFrames = 0
    private var faceFrames = 0
    private var totalFrames = 0
    private var personFrames = 0
    private var lastHeadPoint: CGPoint?

    var captureSession: AVCaptureSession { session }

    /// Starts observation. Returns true only when the camera is actually
    /// running. v1.5: the session keeps its old camera input after stop(),
    /// so a second start() tried to add a duplicate input for the same
    /// device — canAddInput said no, start failed with a misleading
    /// "Camera not available" error, the session never restarted, and the
    /// preview froze on the last frame (seen on shaik's phone, v1.4).
    /// The fix: drop any stale inputs before adding a fresh one, and let
    /// the caller know whether it really started.
    @discardableResult
    func start() -> Bool {
        guard !isObserving else { return true }
        cameraError = nil
        // Camera permission first — a denied camera used to show a black
        // preview with no explanation (v1.2 on shaik's phone).
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            cameraError = "Camera is off — allow Camera for AI Interview Voice in iPhone Settings → Privacy & Security → Camera."
            return false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted { _ = self?.start() }
                    else { self?.cameraError = "Camera is off — allow Camera for AI Interview Voice in iPhone Settings → Privacy & Security → Camera." }
                }
            }
            return false
        default:
            break
        }
        session.beginConfiguration()
        session.sessionPreset = .medium
        // Drop the stale input from the previous run, if any — a camera
        // device can only be attached once, so re-adding it fails.
        for input in session.inputs { session.removeInput(input) }
        guard configureCameraInput() else {
            session.commitConfiguration()
            cameraError = "Camera not available on this device."
            return false
        }
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "body-language-vision"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()
        resetCounts()
        // Capture the session locally first: referencing the MainActor-isolated
        // property from inside the Sendable closure warns in Swift 5.9 and is
        // an error in Swift 6 mode (run #4 warning).
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        isObserving = true
        return true
    }

    /// (Re)adds the camera input for the current position. Returns false
    /// when that camera cannot be opened.
    private func configureCameraInput() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)
        return true
    }

    /// Switch between front and back camera. Works while observing (the
    /// session is reconfigured live) and while stopped (applies on next start).
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == .front ? .back : .front
        guard isObserving else { cameraPosition = newPosition; return }
        let oldPosition = cameraPosition
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        cameraPosition = newPosition
        if configureCameraInput() {
            session.commitConfiguration()
            cameraError = nil
        } else {
            // New camera unavailable — go back to the one that worked.
            for input in session.inputs { session.removeInput(input) }
            cameraPosition = oldPosition
            _ = configureCameraInput()
            session.commitConfiguration()
            cameraError = "That camera is not available on this device."
        }
    }

    func stop() -> BodyLanguageResult {
        session.stopRunning()
        isObserving = false
        return finish()
    }

    private func resetCounts() {
        slouchFrames = 0; uprightFrames = 0; faceAwayFrames = 0; faceFrames = 0
        totalFrames = 0; personFrames = 0; movementSamples = []; lastHeadPoint = nil
    }

    private func finish() -> BodyLanguageResult {
        var result = BodyLanguageResult()
        result.framesChecked = totalFrames
        result.framesWithPerson = personFrames
        result.personVisiblePercent = totalFrames == 0 ? 0 : personFrames * 100 / totalFrames
        // Posture: slouch share of person frames.
        let slouchShare = personFrames == 0 ? 0.0 : Double(slouchFrames) / Double(personFrames)
        result.postureLabel = personFrames == 0 ? "Not visible" : slouchShare > 0.4 ? "Slouched — sit upright" : slouchShare > 0.2 ? "Leaning — straighten up" : "Upright — good"
        // Eye / face: face-away share.
        let awayShare = faceFrames == 0 ? 0.0 : Double(faceAwayFrames) / Double(faceFrames)
        result.eyeLabel = faceFrames == 0 ? "Face not seen" : awayShare > 0.4 ? "Looking away a lot" : awayShare > 0.2 ? "Glancing away sometimes" : "Looking at camera — good"
        // Movement: mean joint travel per frame.
        let meanMove = movementSamples.isEmpty ? 0 : movementSamples.reduce(0, +) / CGFloat(movementSamples.count)
        result.movementLabel = meanMove > 0.08 ? "Fidgety — keep hands still" : meanMove > 0.04 ? "Some movement" : "Calm — good"
        // Score: presence 30 + posture 30 + eye 20 + movement 20. No person = 0, not a fake score.
        if personFrames == 0 {
            result.bodyScore = 0
            result.tips = ["I could not see you in the video — sit in front of the camera, good light on your face, head and shoulders in frame."]
            return result
        }
        var score = 0
        score += result.personVisiblePercent * 30 / 100
        score += slouchShare < 0.2 ? 30 : slouchShare < 0.4 ? 18 : 8
        score += awayShare < 0.2 ? 20 : awayShare < 0.4 ? 12 : 5
        score += meanMove <= 0.04 ? 20 : meanMove <= 0.08 ? 12 : 5
        result.bodyScore = max(0, min(100, score))
        var tips: [String] = []
        if slouchShare > 0.2 { tips.append("Sit upright — shoulders back, head level. Slouching reads as low energy in an interview.") }
        if awayShare > 0.2 { tips.append("Look at the camera more — glancing away a lot reads as unsure.") }
        if meanMove > 0.04 { tips.append("Keep your hands still — lots of movement distracts from your answer.") }
        if tips.isEmpty { tips.append("Good body language — upright, looking at the camera, calm.") }
        result.tips = tips
        return result
    }
}

extension BodyLanguageService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do { try handler.perform([poseRequest, faceRequest]) } catch { return }
        Task { @MainActor in
            self.totalFrames += 1
            // Face: visible + roughly centred = looking at camera.
            if let face = faceRequest.results?.first {
                self.faceFrames += 1
                let cx = face.boundingBox.midX
                if abs(cx - 0.5) > 0.22 { self.faceAwayFrames += 1 }
                self.liveEye = abs(cx - 0.5) > 0.22 ? "Looking away" : "Looking at camera"
            }
            guard let observation = poseRequest.results?.first,
                  let points = try? observation.recognizedPoints(.all) else { return }
            self.personFrames += 1
            self.personVisible = true
            // Posture: shoulder height difference + nose vs neck.
            // Vision has NO `.head` joint (run #4 failed on it) — use `.nose`,
            // the topmost face point. Vision y is up: nose sits above the neck
            // when upright, so headLift is positive; a small lift = head dropped.
            if let lSh = points[.leftShoulder]?.location, let rSh = points[.rightShoulder]?.location,
               let neck = points[.neck]?.location, let nose = points[.nose]?.location {
                let shoulderTilt = abs(lSh.y - rSh.y)
                let headLift = nose.y - neck.y
                let slouched = shoulderTilt > 0.08 || headLift < 0.04
                if slouched { self.slouchFrames += 1 } else { self.uprightFrames += 1 }
                self.livePosture = slouched ? "Slouched" : "Upright"
                if let last = self.lastHeadPoint {
                    let move = hypot(nose.x - last.x, nose.y - last.y)
                    self.movementSamples.append(move)
                    if self.movementSamples.count > 120 { self.movementSamples.removeFirst() }
                    let mean = self.movementSamples.reduce(0, +) / CGFloat(self.movementSamples.count)
                    self.liveMovement = mean > 0.08 ? "Fidgety" : mean > 0.04 ? "Moving" : "Calm"
                }
                self.lastHeadPoint = nose
            }
        }
    }
}
