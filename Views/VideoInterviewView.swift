import SwiftUI
import AVFoundation

/// Video interview screen — v1.1.0 (additive), v1.4.0 full-screen.
/// The camera fills the whole screen (front or back, switchable), with the
/// live body-language badges on top and the controls in a translucent
/// bottom panel — the same full-screen pattern as GYM AI's AI Coach.
/// No video is recorded or saved. Observation starts as soon as you open
/// the tab (so you see yourself straight away) and stops when you leave it.
/// Integrates with InterviewView in v1.1: start body observation when the
/// mic starts, stop it on Stop & Check, and add its bodyScore + tips to
/// the result card alongside the content and English scores.
struct VideoInterviewView: View {
    @StateObject private var bodyService = BodyLanguageService()
    @State private var result: BodyLanguageResult?
    // v1.5: the button state reads straight from bodyService.isObserving —
    // the old local `observing` flag said "observing" even when start()
    // had failed, so the Stop button showed while the video was frozen.

    var body: some View {
        ZStack {
            CameraPreview(session: bodyService.captureSession, mirrored: bodyService.cameraPosition == .front)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    BodyBadge(text: "Posture: \(bodyService.livePosture)", good: bodyService.livePosture == "Upright")
                    BodyBadge(text: "Eyes: \(bodyService.liveEye)", good: bodyService.liveEye == "Looking at camera")
                    BodyBadge(text: "Movement: \(bodyService.liveMovement)", good: bodyService.liveMovement == "Calm")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(bodyService.cameraPosition == .front ? "Front camera" : "Back camera")
                            .font(.subheadline.bold()).foregroundColor(.white)
                        Spacer()
                        Button { bodyService.switchCamera() } label: {
                            Label("Switch", systemImage: "camera.rotate")
                        }.font(.subheadline.bold()).buttonStyle(.bordered).tint(.white)
                    }
                    if let error = bodyService.cameraError {
                        Text(error).font(.subheadline).foregroundColor(.red)
                    }
                    Text("Sit with head and shoulders in frame, good light on your face, look at the camera. On your phone only — no video is saved.")
                        .font(.footnote).foregroundColor(.white.opacity(0.85))
                    HStack(spacing: 10) {
                        if bodyService.isObserving {
                            Button("Stop & check body") {
                                result = bodyService.stop()
                            }.buttonStyle(.borderedProminent).tint(.green)
                        } else {
                            Button("Start video observation") {
                                if bodyService.start() { result = nil }
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                    if let r = result {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Body language: \(r.bodyScore)/100").font(.headline).foregroundColor(.white)
                                Text("Posture: \(r.postureLabel)").font(.subheadline).foregroundColor(.white)
                                Text("Eyes: \(r.eyeLabel)").font(.subheadline).foregroundColor(.white)
                                Text("Movement: \(r.movementLabel)").font(.subheadline).foregroundColor(.white)
                                Text("Visible in frame: \(r.personVisiblePercent)% (\(r.framesWithPerson)/\(r.framesChecked) frames)").font(.caption).foregroundColor(.white.opacity(0.7))
                                ForEach(r.tips, id: \.self) { Text("• \($0)").font(.subheadline).foregroundColor(.white) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.55))
                .cornerRadius(18)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            if !bodyService.isObserving { _ = bodyService.start() }
        }
        .onDisappear {
            if bodyService.isObserving { _ = bodyService.stop() }
        }
    }
}

struct BodyBadge: View {
    let text: String; let good: Bool
    var body: some View {
        Text(text).font(.caption.bold()).padding(6)
            .background((good ? Color.green : Color.orange).opacity(0.85))
            .foregroundColor(.white).cornerRadius(8)
    }
}

/// v1.3: the preview layer IS the view's layer, so it always fills the
/// view exactly. (v1.2 added the preview as a sublayer sized once from
/// view.bounds — which was zero at creation — so the camera stayed black
/// on shaik's phone even while frames were flowing.)
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
        if let connection = uiView.previewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
