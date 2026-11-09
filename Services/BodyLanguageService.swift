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

    func start() {
        guard !isObserving else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "body-language-vision"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()
        resetCounts()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        isObserving = true
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
            // Posture: shoulder height difference + head vs neck.
            if let lSh = points[.leftShoulder]?.location, let rSh = points[.rightShoulder]?.location,
               let neck = points[.neck]?.location, let head = points[.head]?.location {
                let shoulderTilt = abs(lSh.y - rSh.y)
                let headDrop = neck.y - head.y
                let slouched = shoulderTilt > 0.08 || headDrop < 0.04
                if slouched { self.slouchFrames += 1 } else { self.uprightFrames += 1 }
                self.livePosture = slouched ? "Slouched" : "Upright"
                if let last = self.lastHeadPoint {
                    let move = hypot(head.x - last.x, head.y - last.y)
                    self.movementSamples.append(move)
                    if self.movementSamples.count > 120 { self.movementSamples.removeFirst() }
                    let mean = self.movementSamples.reduce(0, +) / CGFloat(self.movementSamples.count)
                    self.liveMovement = mean > 0.08 ? "Fidgety" : mean > 0.04 ? "Moving" : "Calm"
                }
                self.lastHeadPoint = head
            }
        }
    }
}
