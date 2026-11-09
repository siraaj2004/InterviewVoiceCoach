import SwiftUI
import AVFoundation

/// Video interview screen — v1.1.0 (additive).
/// Front-camera preview while you answer, with live body-language badges.
/// No video is recorded or saved. The camera is only observed while you
/// are answering; stopping the answer stops the observation.
/// Integrates with InterviewView in v1.1: start body observation when the
/// mic starts, stop it on Stop & Check, and add its bodyScore + tips to
/// the result card alongside the content and English scores.
struct VideoInterviewView: View {
    @StateObject private var bodyService = BodyLanguageService()
    @State private var result: BodyLanguageResult?
    @State private var observing = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                CameraPreview(session: bodyService.captureSession, mirrored: bodyService.cameraPosition == .front)
                    .frame(height: 320).cornerRadius(14).clipped()
                VStack(alignment: .leading, spacing: 6) {
                    BodyBadge(text: "Posture: \(bodyService.livePosture)", good: bodyService.livePosture == "Upright")
                    BodyBadge(text: "Eyes: \(bodyService.liveEye)", good: bodyService.liveEye == "Looking at camera")
                    BodyBadge(text: "Movement: \(bodyService.liveMovement)", good: bodyService.liveMovement == "Calm")
                }.padding(10)
            }
            Text(bodyService.cameraPosition == .front ? "Front camera" : "Back camera")
                .font(.caption.bold()).foregroundColor(.secondary)
            if let error = bodyService.cameraError {
                Text(error).font(.subheadline).foregroundColor(.red)
            }
            Text("Sit with head and shoulders in frame, good light on your face, look at the camera. The app watches posture, eye direction and fidgeting — on your phone only, no video is saved.")
                .font(.footnote).foregroundColor(.secondary)
            HStack(spacing: 10) {
                if observing {
                    Button("Stop & check body") {
                        result = bodyService.stop(); observing = false
                    }.buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button("Start video observation") {
                        bodyService.start(); observing = true; result = nil
                    }.buttonStyle(.borderedProminent)
                }
                Button { bodyService.switchCamera() } label: {
                    Label("Switch camera", systemImage: "camera.rotate")
                }.buttonStyle(.bordered)
            }
            if let r = result {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Body language: \(r.bodyScore)/100").font(.headline)
                    Text("Posture: \(r.postureLabel)").font(.subheadline)
                    Text("Eyes: \(r.eyeLabel)").font(.subheadline)
                    Text("Movement: \(r.movementLabel)").font(.subheadline)
                    Text("Visible in frame: \(r.personVisiblePercent)% (\(r.framesWithPerson)/\(r.framesChecked) frames)").font(.caption).foregroundColor(.secondary)
                    ForEach(r.tips, id: \.self) { Text("• \($0)").font(.subheadline) }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground)).cornerRadius(12)
            }
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
