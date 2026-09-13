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
        guard session.isRunning else {
            if status != .denied && status != .unavailable { status = .inactive }
            return
        }
        session.stopRunning()
        status = .inactive
        isFaceVisible = false
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
        guard !session.isRunning else {
            status = .running
            return
        }
        guard configureIfNeeded() else { return }
        session.startRunning()
        status = .running
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        guard let device = AVCaptureDevice.default(for: .video) else {
            status = .unavailable
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .medium
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                status = .failed
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
            status = .failed
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
            publish(faceCenterY: Double(face.boundingBox.midY), faceHeight: Double(face.boundingBox.height))
        } catch {
            publishNoFace()
        }
    }

    private func publishNoFace() {
        DispatchQueue.main.async { [weak self] in
            self?.isFaceVisible = false
        }
    }

    private func publish(faceCenterY: Double, faceHeight: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastFaceCenterY = faceCenterY
            self.lastFaceHeight = faceHeight
            self.isFaceVisible = true

            guard let baselineY = self.calibrationFaceCenterY,
                  let baselineHeight = self.calibrationFaceHeight,
                  let baselineElevation = self.calibrationElevationAngle,
                  let baselineDistance = self.calibrationViewingDistance,
                  faceHeight > 0 else { return }

            // Vision's normalized Y axis rises upward. A 55° vertical camera
            // field-of-view approximation is deliberately bounded: it tracks
            // relative seated movement after calibration, not absolute pose.
            let elevation = min(max(baselineElevation + (faceCenterY - baselineY) * 55, 0), 60)
            let distance = min(max(baselineDistance * baselineHeight / faceHeight, 1), 6)
            self.estimatedElevationAngle = elevation
            self.estimatedViewingDistance = distance
        }
    }
}
