import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import Vision

/// Camera-assisted, calibrated viewer-position tracking.
///
/// This intentionally never records, writes, or transmits camera frames. The
/// built-in camera is attached to the lid, so it cannot independently observe
/// the keyboard deck and gravity; `baseTiltAngle` remains a user calibration.
final class ViewerPositionTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum Status: Equatable {
        case inactive
        case requestingPermission
        case running
        case denied
        case unavailable
        case failed
    }

    @Published private(set) var status: Status = .inactive
    @Published private(set) var isFaceVisible = false
    @Published private(set) var estimatedElevationAngle: Double?
    @Published private(set) var estimatedViewingDistance: Double?
    @Published private(set) var estimatedBaseTiltAngle: Double?

    var isRunning: Bool { status == .running }
    var canCalibrate: Bool { lastFaceCenterY != nil && lastFaceHeight != nil }

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: "MacFold.viewerCamera", qos: .userInitiated)
    private var isConfigured = false
    private var lastFrameTime: CFAbsoluteTime = 0
    private var lastFaceCenterY: Double?
    private var lastFaceHeight: Double?
    private var calibrationFaceCenterY: Double?
    private var calibrationFaceHeight: Double?
    private var calibrationElevationAngle: Double?
    private var calibrationViewingDistance: Double?
    private var hingeAngle: Double = 90
    private var baseTiltAngle: Double = 0

    /// The neutral eye elevation used when no one-off distance calibration is
    /// available. Face position moves this value continuously at runtime.
    private static let neutralEyeElevation: Double = 20
    private static let verticalCameraFieldOfView: Double = 55

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureAndStart() : self.setDenied()
                }
            }
        case .denied, .restricted:
            setDenied()
        @unknown default:
            setDenied()
        }
    }

    func stop() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                if self.status != .denied && self.status != .unavailable { self.status = .inactive }
                self.isFaceVisible = false
            }
        }
    }

    /// The camera rotates with the lid. Feed the physical hinge reading so a
    /// closing lid is not misinterpreted as the viewer moving their eyes.
    func updateLidGeometry(hingeAngle: Double, baseTiltAngle: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.hingeAngle = hingeAngle
            self?.baseTiltAngle = baseTiltAngle
        }
    }

    /// Establishes the current seated position as the reference for later
    /// relative face movement and apparent face-size measurements.
    func calibrate(observerElevation: Double, viewingDistance: Double) -> Bool {
        guard let centre = lastFaceCenterY, let height = lastFaceHeight else { return false }
        calibrationFaceCenterY = centre
        calibrationFaceHeight = height
        calibrationElevationAngle = observerElevation
        calibrationViewingDistance = viewingDistance
        estimatedElevationAngle = observerElevation
        estimatedViewingDistance = viewingDistance
        return true
    }

    private func setDenied() {
        status = .denied
        isFaceVisible = false
    }

    private func configureAndStart() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else {
                DispatchQueue.main.async { self.status = .running }
                return
            }
            guard self.configureIfNeeded() else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.status = .running
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        guard let device = AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async { self.status = .unavailable }
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .medium
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.status = .failed }
                return false
            }
            session.addInput(input)
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            output.setSampleBufferDelegate(self, queue: cameraQueue)
            session.addOutput(output)
            session.commitConfiguration()
            isConfigured = true
            return true
        } catch {
            DispatchQueue.main.async { self.status = .failed }
            return false
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameTime >= 1.0 / 12 else { return }
        lastFrameTime = now

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([request])
            guard let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
                publishNoFace()
                return
            }
            let faceCenterY = Double(face.boundingBox.midY)
            let eyeCenterY = normalizedEyeCenterY(for: face, in: sampleBuffer) ?? faceCenterY
            let facePitch = face.pitch?.doubleValue
            publish(eyeCenterY: eyeCenterY, faceHeight: Double(face.boundingBox.height), facePitch: facePitch)
        } catch {
            publishNoFace()
        }
    }

    private func publishNoFace() {
        DispatchQueue.main.async { [weak self] in
            self?.isFaceVisible = false
        }
    }

    private func normalizedEyeCenterY(for face: VNFaceObservation, in sampleBuffer: CMSampleBuffer) -> Double? {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let size = CGSize(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
        var points: [CGPoint] = []
        if let leftEye = face.landmarks?.leftEye {
            points += leftEye.pointsInImage(imageSize: size)
        }
        if let rightEye = face.landmarks?.rightEye {
            points += rightEye.pointsInImage(imageSize: size)
        }
        guard !points.isEmpty, size.height > 0 else { return nil }
        return Double(points.reduce(0) { $0 + $1.y } / CGFloat(points.count) / size.height)
    }

    private func publish(eyeCenterY: Double, faceHeight: Double, facePitch: Double?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastFaceCenterY = eyeCenterY
            self.lastFaceHeight = faceHeight
            self.isFaceVisible = true

            // Vision's normalized Y axis rises upward. The webcam's optical
            // axis rotates with the lid, so combine its local eye angle with
            // the measured physical screen angle before updating the room-
            // relative observer elevation used by the renderer.
            let halfField = Self.verticalCameraFieldOfView * .pi / 360
            let cameraOffset = atan(tan(halfField) * (eyeCenterY - 0.5) * 2) * 180 / .pi
            let cameraWorldElevation = self.hingeAngle + self.baseTiltAngle - 90
            let elevation = min(max(cameraWorldElevation + cameraOffset, 0), 60)
            self.estimatedElevationAngle = elevation

            // Estimate the base tilt relative to gravity from head pitch:
            // An upright observer facing the display has head pitch ≈ -(cameraWorldElevation - cameraOffset).
            // Hence: baseTilt ≈ 90 - hingeAngle - pitchDegrees + cameraOffset.
            if let pitch = facePitch {
                let pitchDegrees = pitch * 180 / .pi
                let rawBaseTilt = 90 - self.hingeAngle - pitchDegrees + cameraOffset
                let clampedBaseTilt = min(max(rawBaseTilt, 0), 35)
                if let current = self.estimatedBaseTiltAngle {
                    self.estimatedBaseTiltAngle = current * 0.85 + clampedBaseTilt * 0.15
                } else {
                    self.estimatedBaseTiltAngle = clampedBaseTilt
                }
            }

            // A single RGB camera cannot reliably derive absolute distance
            // without a known physical reference. Keep that estimate opt-in
            // and relative to the user's explicit calibration baseline.
            if let baselineHeight = self.calibrationFaceHeight,
               let baselineDistance = self.calibrationViewingDistance,
               faceHeight > 0 {
                self.estimatedViewingDistance = min(max(baselineDistance * baselineHeight / faceHeight, 1), 6)
            }
        }
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }
}
