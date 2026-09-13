import AppKit
import SwiftUI

/// Owns the standard macOS Settings window opened by Command-comma.
@MainActor
final class SettingsWindowController: NSWindowController {

    init(
        preferences: Preferences,
        controller: LidController,
        viewerTracker: ViewerPositionTracker,
        updateController: UpdateController
    ) {
        let content = SettingsView(
            preferences: preferences,
            controller: controller,
            viewerTracker: viewerTracker,
            updateController: updateController,
            onQuit: { NSApp.terminate(nil) }
        )
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Mac Fold Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 380, height: 620))
        window.minSize = NSSize(width: 360, height: 480)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showSettings() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
