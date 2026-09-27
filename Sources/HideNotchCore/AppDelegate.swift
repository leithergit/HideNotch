import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let overlay = OverlayController(screens: SystemScreens(), makeWindow: { BarWindow() })
    private var statusController: StatusItemController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        overlay.isEnabled = preferences.overlayEnabled

        let status = StatusItemController(preferences: preferences, overlay: overlay, loginItem: SystemLoginItem())
        status.install()
        statusController = status

        NotificationCenter.default.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    @objc private func layoutChanged(_ notification: Notification) {
        overlay.refresh()
    }
}
