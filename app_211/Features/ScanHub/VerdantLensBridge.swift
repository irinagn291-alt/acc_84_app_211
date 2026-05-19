import AVFoundation
import SwiftUI
import UIKit

struct VerdantLensBridge: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VerdantLensController {
        VerdantLensController(onCode: onCode, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: VerdantLensController, context: Context) {
        uiViewController.onCode = onCode
        uiViewController.onCancel = onCancel
    }

    final class VerdantLensOverlay: UIView {
        private var dimColor: UIColor {
            UIColor(red: 8 / 255, green: 30 / 255, blue: 20 / 255, alpha: 0.65)
        }

        private var accentColor: UIColor {
            UIColor(red: 0x2E / 255, green: 0xCC / 255, blue: 0x71 / 255, alpha: 1)
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            let bounds = self.bounds
            let w = min(280, bounds.width - 48)
            let h = min(200, bounds.height * 0.32)
            let cut = CGRect(x: (bounds.width - w) / 2, y: bounds.midY - h / 2 - 20, width: w, height: h)

            ctx.setFillColor(dimColor.cgColor)
            ctx.fill(bounds)
            ctx.setBlendMode(.clear)
            ctx.addPath(UIBezierPath(roundedRect: cut, cornerRadius: 28).cgPath)
            ctx.fillPath()
            ctx.setBlendMode(.normal)

            accentColor.setStroke()
            let lineW: CGFloat = 4
            let corner: CGFloat = 42
            let inset = lineW / 2

            func strokeCorner(_ r: CGRect, top: Bool, left: Bool) {
                let p = UIBezierPath()
                if top, left {
                    p.move(to: CGPoint(x: r.minX + corner, y: r.minY + inset))
                    p.addLine(to: CGPoint(x: r.minX + inset, y: r.minY + inset))
                    p.addLine(to: CGPoint(x: r.minX + inset, y: r.minY + corner))
                } else if top, !left {
                    p.move(to: CGPoint(x: r.maxX - corner, y: r.minY + inset))
                    p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY + inset))
                    p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY + corner))
                } else if !top, left {
                    p.move(to: CGPoint(x: r.minX + inset, y: r.maxY - corner))
                    p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY - inset))
                    p.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY - inset))
                } else {
                    p.move(to: CGPoint(x: r.maxX - inset, y: r.maxY - corner))
                    p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY - inset))
                    p.addLine(to: CGPoint(x: r.maxX - corner, y: r.maxY - inset))
                }
                p.lineWidth = lineW
                p.lineCapStyle = .round
                p.stroke()
            }
            strokeCorner(cut, top: true, left: true)
            strokeCorner(cut, top: true, left: false)
            strokeCorner(cut, top: false, left: true)
            strokeCorner(cut, top: false, left: false)
        }
    }

    final class VerdantLensController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: (String) -> Void
        var onCancel: () -> Void

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var overlay: VerdantLensOverlay?
        private var topBar: UIView!
        private var torchBtn: UIButton!
        private var centerMessage: UILabel!
        private var bottomHint: UILabel!

        init(onCode: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onCode = onCode
            self.onCancel = onCancel
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            buildChrome()
            resolveCameraAccess()
        }

        private func buildChrome() {
            let topBar = UIView()
            topBar.translatesAutoresizingMaskIntoConstraints = false
            topBar.backgroundColor = UIColor(white: 0, alpha: 0.35)
            view.addSubview(topBar)
            self.topBar = topBar

            let closeBtn = makeCircleButton(symbol: "xmark") { [weak self] in
                self?.session.stopRunning()
                self?.onCancel()
            }
            let torchBtn = makeCircleButton(symbol: "flashlight.on.fill") { [weak self] in
                self?.toggleTorch()
            }
            torchBtn.isEnabled = false
            torchBtn.alpha = 0.45
            self.torchBtn = torchBtn

            let title = UILabel()
            title.translatesAutoresizingMaskIntoConstraints = false
            title.text = "Scan barcode or QR"
            title.textColor = .white
            title.font = .systemFont(ofSize: 16, weight: .heavy)

            topBar.addSubview(closeBtn)
            topBar.addSubview(title)
            topBar.addSubview(torchBtn)

            let centerMessage = UILabel()
            centerMessage.translatesAutoresizingMaskIntoConstraints = false
            centerMessage.textColor = .white
            centerMessage.font = .systemFont(ofSize: 15, weight: .semibold)
            centerMessage.textAlignment = .center
            centerMessage.numberOfLines = 0
            centerMessage.isHidden = true
            view.addSubview(centerMessage)
            self.centerMessage = centerMessage

            let bottomHint = UILabel()
            bottomHint.translatesAutoresizingMaskIntoConstraints = false
            bottomHint.text = "Hold steady inside the frame. Scanning starts automatically."
            bottomHint.textColor = UIColor.white.withAlphaComponent(0.82)
            bottomHint.font = .systemFont(ofSize: 14, weight: .semibold)
            bottomHint.textAlignment = .center
            bottomHint.numberOfLines = 0
            view.addSubview(bottomHint)
            self.bottomHint = bottomHint

            NSLayoutConstraint.activate([
                topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topBar.heightAnchor.constraint(equalToConstant: 64),
                closeBtn.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
                closeBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                closeBtn.widthAnchor.constraint(equalToConstant: 46),
                closeBtn.heightAnchor.constraint(equalToConstant: 46),
                torchBtn.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
                torchBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                torchBtn.widthAnchor.constraint(equalToConstant: 46),
                torchBtn.heightAnchor.constraint(equalToConstant: 46),
                title.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
                title.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                centerMessage.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
                centerMessage.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
                centerMessage.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                bottomHint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
                bottomHint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
                bottomHint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            ])
        }

        private func resolveCameraAccess() {
            #if targetEnvironment(simulator)
            centerMessage.isHidden = false
            centerMessage.text = "Camera is not available in Simulator.\nUse manual barcode entry on the Scan tab."
            bottomHint.isHidden = true
            return
            #endif
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureCaptureSessionAndStart()
            case .notDetermined:
                centerMessage.isHidden = false
                centerMessage.text = "Allow camera access to scan products."
                bottomHint.isHidden = true
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if granted {
                            self.centerMessage.isHidden = true
                            self.bottomHint.isHidden = false
                            self.configureCaptureSessionAndStart()
                        } else {
                            self.showAccessDenied()
                        }
                    }
                }
            default:
                showAccessDenied()
            }
        }

        private func showAccessDenied() {
            centerMessage.isHidden = false
            centerMessage.text = "Camera access is off. Enable it in Settings to scan."
            bottomHint.isHidden = true
        }

        private func configureCaptureSessionAndStart() {
            session.beginConfiguration()
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else {
                session.commitConfiguration()
                centerMessage.isHidden = false
                centerMessage.text = "Could not start the camera."
                return
            }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .pdf417, .qr, .code39]
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            previewLayer = layer

            if overlay == nil {
                let ov = VerdantLensOverlay(frame: view.bounds)
                ov.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.insertSubview(ov, belowSubview: topBar)
                overlay = ov
            }
            torchBtn.isEnabled = true
            torchBtn.alpha = 1
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
            overlay?.frame = view.bounds
            overlay?.setNeedsDisplay()
        }

        private func makeCircleButton(symbol: String, action: @escaping () -> Void) -> UIButton {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
            b.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
            b.tintColor = .white
            b.backgroundColor = UIColor.white.withAlphaComponent(0.16)
            b.layer.cornerRadius = 23
            b.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return b
        }

        private func toggleTorch() {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { return }
            session.stopRunning()
            onCode(value)
        }
    }
}
