import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: LidController?
    private var viewerTracker: ViewerPositionTracker?
    private var updateController: UpdateController?
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice("launched, screen recording granted: \(CGPreflightScreenCaptureAccess())")
        let preferences = Preferences.shared
        let viewerTracker = ViewerPositionTracker()
        let controller = LidController(preferences: preferences, viewerTracker: viewerTracker)
        let updateController = UpdateController()
        self.controller = controller
        self.viewerTracker = viewerTracker
        self.updateController = updateController
        let settingsWindow = SettingsWindowController(
            preferences: preferences,
            controller: controller,
            viewerTracker: viewerTracker,
            updateController: updateController
        )
        self.settingsWindowController = settingsWindow
        statusItemController = StatusItemController(
            controller: controller,
            preferences: preferences,
            viewerTracker: viewerTracker,
            updateController: updateController,
            openSettings: { [weak settingsWindow] in
                settingsWindow?.showSettings()
            }
        )
        installApplicationMenu()
        controller.start()
        updateController.checkIfDue()
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

    @objc private func checkForUpdates(_ sender: Any?) {
        updateController?.checkForUpdates()
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
        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updatesItem.target = self
        applicationMenu.addItem(updatesItem)
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
