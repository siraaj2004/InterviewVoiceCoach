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
    @StateObject private var body = BodyLanguageService()
    @State private var result: BodyLanguageResult?
    @State private var observing = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                CameraPreview(session: body.captureSession)
                    .frame(height: 320).cornerRadius(14).clipped()
                VStack(alignment: .leading, spacing: 6) {
                    BodyBadge(text: "Posture: \(body.livePosture)", good: body.livePosture == "Upright")
                    BodyBadge(text: "Eyes: \(body.liveEye)", good: body.liveEye == "Looking at camera")
                    BodyBadge(text: "Movement: \(body.liveMovement)", good: body.liveMovement == "Calm")
                }.padding(10)
            }
            Text("Sit with head and shoulders in frame, good light on your face, look at the camera. The app watches posture, eye direction and fidgeting — on your phone only, no video is saved.")
                .font(.footnote).foregroundColor(.secondary)
            HStack(spacing: 10) {
                if observing {
                    Button("Stop & check body") {
                        result = body.stop(); observing = false
                    }.buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button("Start video observation") {
                        body.start(); observing = true; result = nil
                    }.buttonStyle(.borderedProminent)
                }
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

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
