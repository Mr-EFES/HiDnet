import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    let onScan: (String) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScannerCamera(onScan: onScan, onError: { error = $0 }).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(error ?? "Наведите камеру на QR-код OpenFlux")
                    .multilineTextAlignment(.center)
                Button("Закрыть") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(24).frame(maxWidth: .infinity).background(.ultraThinMaterial)
        }
    }
}

private struct ScannerCamera: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        ScannerController(onScan: onScan, onError: onError)
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: ScannerController, coordinator: ()) {
        uiViewController.stop()
    }
}

private final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "HiDnet.QRCamera")
    private var preview: AVCaptureVideoPreviewLayer?
    private var scanned = false
    private var stopped = false
    private let onScan: (String) -> Void
    private let onError: (String) -> Void

    init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onScan = onScan
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            if allowed { self.sessionQueue.async { self.configure() } }
            else {
                DispatchQueue.main.async {
                    self.onError("Разрешите доступ к камере в настройках iPhone или вставьте ссылку вручную.")
                }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    func stop() {
        sessionQueue.async {
            self.stopped = true
            self.session.stopRunning()
        }
    }

    private func configure() {
        guard !stopped else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            DispatchQueue.main.async { self.onError("Камера недоступна. Вставьте ссылку вручную.") }
            return
        }
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.onError("Сканер QR-кодов недоступен.") }
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        session.startRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !scanned,
              let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = code.stringValue else { return }
        scanned = true
        stop()
        onScan(value)
    }
}
