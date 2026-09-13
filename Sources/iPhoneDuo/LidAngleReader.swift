// Derived from the HID probing technique in samhenrigold/LidAngleSensor.
// Copyright 2026 Sam Gold. Licensed under Apache-2.0; see NOTICE.

import Foundation
import IOKit.hid
import Observation

/// Reads the internal Apple lid-angle feature report. This is undocumented
/// hardware behavior and is deliberately isolated from the UI.
@Observable
@MainActor
final class LidAngleReader {
    private(set) var angle = 92.0
    private(set) var isAvailable = false
    private(set) var status = "Checking lid-angle sensor…"

    // These must be explicitly unsafe for synchronous deinitialization.
    // They are otherwise only touched on the main actor.
    @ObservationIgnored nonisolated(unsafe) private var device: IOHIDDevice?
    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    @ObservationIgnored private var report = [UInt8](repeating: 0, count: 8)
    @ObservationIgnored nonisolated(unsafe) private var isOpen = false
    private let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    init() {
        device = findSensor()
        if device == nil { status = "No readable lid-angle sensor found on this Mac." }
    }

    deinit {
        timer?.invalidate()
        if isOpen, let device { IOHIDDeviceClose(device, noOptions) }
    }

    func start() {
        guard timer == nil, let device else { return }
        guard IOHIDDeviceOpen(device, noOptions) == kIOReturnSuccess else {
            status = "The lid-angle sensor was found but could not be opened."
            return
        }
        isOpen = true
        isAvailable = true
        status = "Live internal lid-angle sensor"
        timer = .scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if isOpen, let device { IOHIDDeviceClose(device, noOptions); isOpen = false }
        isAvailable = false
    }

    private func poll() {
        guard let device else { return }
        var length = CFIndex(report.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return }
        let rawAngle = Double(UInt16(report[2]) << 8 | UInt16(report[1]))
        guard (0...180).contains(rawAngle) else { return }
        angle = rawAngle
    }

    private func findSensor() -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, noOptions)
        guard IOHIDManagerOpen(manager, noOptions) == kIOReturnSuccess else { return nil }
        defer { IOHIDManagerClose(manager, noOptions) }
        let match: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "UsagePage": 0x0020,
            "Usage": 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, noOptions) == kIOReturnSuccess else { continue }
            defer { IOHIDDeviceClose(candidate, noOptions) }
            var probe = [UInt8](repeating: 0, count: 8)
            var length = CFIndex(probe.count)
            if IOHIDDeviceGetReport(candidate, kIOHIDReportTypeFeature, 1, &probe, &length) == kIOReturnSuccess, length >= 3 {
                return candidate
            }
        }
        return nil
    }
}
