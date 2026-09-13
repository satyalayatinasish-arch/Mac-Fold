import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: LidController
    @ObservedObject var viewerTracker: ViewerPositionTracker
    @ObservedObject var updateController: UpdateController

    /// Empty means following the system language.
    @AppStorage("settingsLanguage") private var language = ""

    private var selectedLanguage: SettingsLanguage {
        SettingsLanguage(rawValue: language) ?? .preferred
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localized(key)
    }

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasScreenPermission = CGPreflightScreenCaptureAccess()
    @State private var settingsOpenFailed = false

    var onQuit: () -> Void

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? updateController.currentVersion
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private static let width: CGFloat = 340
    private static let inset: CGFloat = 14
    private static let bodyHeight: CGFloat = 430
    private static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
    )!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Self.inset)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Divider()
            if controller.isSensorAvailable {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        MacBookHingeView(
                            angle: controller.currentAngle,
                            isEnabled: preferences.isEnabled,
                            compact: true,
                            observerElevationAngle: preferences.observerElevationAngle,
                            baseTiltAngle: preferences.baseTiltAngle
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)

                        switches

                        LiquidGlassActionButton(
                            title: localized("Test Fold Effect"),
                            icon: "sparkles",
                            tint: .cyan
                        ) {
                            controller.runPreview()
                        }
                        .padding(.vertical, 2)

                        if !hasScreenPermission {
                            permissionNotice
                        }
                        startGroup
                        lookGroup
                        perspectiveGroup
                        observerPositionGroup
                        cameraAssistedGroup
                        updateGroup
                    }
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 10)
                }
                .frame(height: Self.bodyHeight)
            } else {
                unavailableNotice
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 12)
            }
            Divider()
            appGroup
                .padding(.horizontal, Self.inset)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(width: Self.width)
        .preferredColorScheme(preferences.colorScheme)
        .onAppear {
            hasScreenPermission = CGPreflightScreenCaptureAccess()
            synchronizeCameraTracking()
        }
        .onChange(of: preferences.isCameraViewTracking) { _, _ in
            synchronizeCameraTracking()
        }
        .onChange(of: viewerTracker.estimatedElevationAngle) { _, _ in
            applyCameraEstimate()
        }
        .onChange(of: viewerTracker.estimatedViewingDistance) { _, _ in
            applyCameraEstimate()
        }
        .onChange(of: viewerTracker.estimatedBaseTiltAngle) { _, _ in
            applyCameraEstimate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasScreenPermission = CGPreflightScreenCaptureAccess()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Mac Fold").font(.title2.weight(.semibold))
                Text(String(format: localized("Version %@"), appVersion))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ThemeSwitchButton(preferences: preferences)
        }
    }

    private var unavailableNotice: some View {
        Text(localized("This Mac has no lid angle sensor. Only some MacBook models have one."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var switches: some View {
        VStack(alignment: .leading, spacing: 4) {
            toggleRow(
                localized("Depth effect"),
                isOn: $preferences.isEnabled,
                help: localized("Leans the screen away as the lid closes.")
            )
            toggleRow(
                localized("Live rendering"),
                isOn: $preferences.isLivePicture,
                help: localized("Off holds the frame from when the effect started.")
            )
            .disabled(!preferences.isEnabled)
        }
    }

    private var startGroup: some View {
        group(localized("Start")) {
            toggleRow(
                localized("Timeout"),
                isOn: $preferences.isTimeoutEnabled,
                help: localized("Ends the effect once the angle stops changing.")
            )
            slider(
                localized("Start angle"), value: $preferences.thresholdAngle, in: 5...130, format: "%.0f°",
                help: localized("The effect starts at this angle.")
            )
            slider(
                localized("Full effect after"), value: $preferences.blurSpan, in: 5...60, format: "%.0f°",
                help: localized("Degrees of further closing to reach full strength.")
            )
        }
    }

    private var lookGroup: some View {
        group(localized("Look")) {
            slider(
                localized("Blur"), value: $preferences.maxBlurRadius, in: 10...160, format: "%.0f pt",
                help: localized("Blur radius at the far edge.")
            )
            slider(
                localized("Blur spread"), value: $preferences.blurEvenness, in: 0...1, format: "%.0f%%", scale: 100,
                help: localized("0 blurs the far edge only, 100 the whole picture.")
            )
            slider(
                localized("Dimming"), value: $preferences.maxDim, in: 0...1, format: "%.0f%%", scale: 100,
                help: localized("How dark the far edge goes.")
            )
            slider(
                localized("Dimming spread"), value: $preferences.dimReach, in: 0.2...1, format: "%.0f%%", scale: 100,
                help: localized("Everything above this height goes fully dark.")
            )
        }
    }

    private var perspectiveGroup: some View {
        group(localized("Perspective")) {
            slider(
                localized("Lean back"), value: $preferences.recession, in: 0...3, format: "%.1f×",
                help: localized("Degrees of lean per degree of closing. 1 holds it still.")
            )
            slider(
                localized("Perspective"), value: perspective, in: 0...1, format: "%.0f%%", scale: 100,
                help: localized("0 keeps the sides parallel, 100 converges sharply.")
            )
        }
    }

    private var observerPositionGroup: some View {
        group(localized("Observer Position")) {
            slider(
                localized("Eye Height"), value: $preferences.observerElevationAngle, in: 0...60, format: "%.0f°",
                help: localized("Eye height above the screen centre. Higher values strengthen the view-based fold.")
            )
            slider(
                localized("Base Tilt"), value: $preferences.baseTiltAngle, in: 0...30, format: "%.0f°",
                help: localized("Tilt of the keyboard deck above a flat desk or floor.")
            )
        }
    }

    private var cameraAssistedGroup: some View {
        group(localized("Camera-Assisted Viewpoint")) {
            toggleRow(
                localized("Use camera for viewer position"),
                isOn: $preferences.isCameraViewTracking,
                help: localized("Processes face position on this Mac only. No video is saved or uploaded.")
            )
            HStack(spacing: 6) {
                Image(systemName: viewerTracker.isFaceVisible ? "face.smiling" : "camera.fill")
                    .foregroundStyle(viewerTracker.isFaceVisible ? .green : .secondary)
                Text(cameraStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localized("Calibrate")) {
                    _ = viewerTracker.calibrate(
                        observerElevation: preferences.observerElevationAngle,
                        viewingDistance: preferences.viewingDistance
                    )
                }
                .disabled(!preferences.isCameraViewTracking || !viewerTracker.canCalibrate)
                .controlSize(.small)
            }
            Text(localized("Sit naturally, enable the camera, then calibrate. Base Tilt remains manual because a lid-mounted camera cannot independently measure the keyboard deck against the ground."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var updateGroup: some View {
        group(localized("Updates")) {
            HStack {
                Text(localized("Current Version"))
                Spacer()
                Text(String(format: "%@ (%@)", appVersion, appBuild))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            toggleRow(
                localized("Automatically check for updates"),
                isOn: $preferences.isAutomaticUpdateChecks,
                help: localized("Checks the public Mac Fold release feed once per day. It never installs an update without your approval.")
            )
            HStack {
                Text(updateStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if updateController.status == .updateAvailable {
                    Button(localized("Get Update"), action: updateController.openLatestRelease)
                } else {
                    Button(localized("Check for Updates"), action: updateController.checkForUpdates)
                        .disabled(updateController.status == .checking)
                }
            }
            .controlSize(.small)
            Text(localized("In-place installation is enabled only after the signed updater setup in AUTO_UPDATE_CHECKLIST.md is complete."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var updateStatusText: String {
        switch updateController.status {
        case .idle: return localized("No update check has run yet")
        case .checking: return localized("Checking for updates…")
        case .upToDate: return localized("Mac Fold is up to date")
        case .updateAvailable:
            return String(format: localized("Version %@ is available"), updateController.latestVersion ?? "")
        case .failed: return localized("Could not check for updates")
        }
    }

    private var cameraStatusText: String {
        switch viewerTracker.status {
        case .inactive: return localized("Camera is off")
        case .requestingPermission: return localized("Requesting camera permission")
        case .running:
            return viewerTracker.isFaceVisible
                ? localized("Face detected — calibrated values update live")
                : localized("Camera is on — face not detected")
        case .denied: return localized("Camera permission is required")
        case .unavailable: return localized("No camera is available")
        case .failed: return localized("Camera could not start")
        }
    }

    private var appGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localized("Appearance"))
                Spacer()
                Picker("", selection: $preferences.appTheme) {
                    Text(localized("System")).tag("system")
                    Text(localized("Light")).tag("light")
                    Text(localized("Dark")).tag("dark")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel(localized("Appearance"))
            }
            HStack {
                Text(localized("Language"))
                Spacer()
                Picker("", selection: $language) {
                    Text(localized("System")).tag("")
                    Text(verbatim: "English").tag(SettingsLanguage.english.rawValue)
                    Text(localized("Chinese (Simplified)")).tag(SettingsLanguage.chinese.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel(localized("Language"))
            }
            toggleRow(localized("Show angle in menu bar"), isOn: $preferences.showsAngleInMenuBar, help: nil)
            toggleRow(localized("Launch at login"), isOn: $launchesAtLogin, help: nil)
                .onChange(of: launchesAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            HStack {
                Button(localized("Reset")) { preferences.resetToDefaults() }
                Spacer()
                Button(localized("Quit"), action: onQuit)
            }
            .controlSize(.small)
            .padding(.top, 2)

            HStack {
                Spacer()
                Text(verbatim: "Mac Fold v\(appVersion) (\(appBuild))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, help: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel(title)
            }
            description(help)
        }
    }

    @ViewBuilder
    private func description(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var perspective: Binding<Double> {
        Binding(
            get: { (Preferences.farthestEye - preferences.viewingDistance) / Preferences.eyeRange },
            set: { preferences.viewingDistance = Preferences.farthestEye - $0 * Preferences.eyeRange }
        )
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("Screen Recording permission is required to show the depth effect."))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(localized("Open System Settings")) {
                    openScreenRecordingSettings()
                }
                .controlSize(.small)
            }
            if settingsOpenFailed {
                Text(localized("Could not open System Settings. Open it manually and enable screen recording for Mac Fold under Privacy & Security."))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func openScreenRecordingSettings() {
        settingsOpenFailed = false
        Task { @MainActor in
            do {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.open(Self.screenRecordingSettingsURL, configuration: configuration)
            } catch {
                settingsOpenFailed = true
            }
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .disabled(!preferences.isEnabled)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: String,
        scale: Double = 1,
        help: String? = nil
    ) -> some View {
        let reading = String(format: format, value.wrappedValue * scale)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(reading)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(reading)
            description(help)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func synchronizeCameraTracking() {
        if preferences.isCameraViewTracking {
            viewerTracker.start()
        } else {
            viewerTracker.stop()
        }
    }

    private func applyCameraEstimate() {
        guard preferences.isCameraViewTracking else { return }
        if let elevation = viewerTracker.estimatedElevationAngle,
           abs(preferences.observerElevationAngle - elevation) >= 0.2 {
            preferences.observerElevationAngle = elevation
        }
        if let distance = viewerTracker.estimatedViewingDistance,
           abs(preferences.viewingDistance - distance) >= 0.1 {
            preferences.viewingDistance = distance
        }
        if let baseTilt = viewerTracker.estimatedBaseTiltAngle,
           abs(preferences.baseTiltAngle - baseTilt) >= 0.3 {
            preferences.baseTiltAngle = baseTilt
        }
    }
}

private extension View {
    func pointingHand() -> some View {
        modifier(PointingHand())
    }
}

private struct PointingHand: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !pushed {
                    NSCursor.pointingHand.push()
                    pushed = true
                } else if !inside, pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}
