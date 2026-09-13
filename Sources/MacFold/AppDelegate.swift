import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: LidController?
    private var viewerTracker: ViewerPositionTracker?
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice("launched, screen recording granted: \(CGPreflightScreenCaptureAccess())")
        let preferences = Preferences.shared
        let controller = LidController(preferences: preferences)
        let viewerTracker = ViewerPositionTracker()
        self.controller = controller
        self.viewerTracker = viewerTracker
        let settingsWindow = SettingsWindowController(
            preferences: preferences,
            controller: controller,
            viewerTracker: viewerTracker
        )
        self.settingsWindowController = settingsWindow
        statusItemController = StatusItemController(
            controller: controller,
            preferences: preferences,
            viewerTracker: viewerTracker,
            openSettings: { [weak settingsWindow] in
                settingsWindow?.showSettings()
            }
        )
        installApplicationMenu()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        viewerTracker?.stop()
    }

    @objc private func openSettings(_ sender: Any?) {
        settingsWindowController?.showSettings()
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func installApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem(title: "Mac Fold", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "Mac Fold")

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Mac Fold",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        applicationMenu.addItem(quitItem)

        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }
}
