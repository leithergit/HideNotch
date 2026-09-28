import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private let confirmEnable: @MainActor () -> Bool
    private var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: L10n.hideNotch, action: #selector(toggleOverlay), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLoginItem), keyEquivalent: "")

    public init(
        preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling,
        confirmEnable: @escaping @MainActor () -> Bool = StatusItemController.askToEnable
    ) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        self.confirmEnable = confirmEnable
        super.init()

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        for item in [overlayItem, loginMenuItem, quitItem] {
            item.target = self
        }
        menu.addItem(overlayItem)
        menu.addItem(loginMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.delegate = self
        syncMenuState()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NotchIcon.menuBarImage()
        item.menu = menu
        statusItem = item
    }

    public func menuWillOpen(_ menu: NSMenu) {
        syncMenuState()
    }

    @objc func toggleOverlay() {
        let enable = !preferences.overlayEnabled
        if enable && !confirmEnable() {
            syncMenuState()
            return
        }
        preferences.overlayEnabled = enable
        overlay.isEnabled = enable
        syncMenuState()
    }

    /// Activates the (accessory) app before presenting the alert, so it doesn't appear behind other windows.
    public static func askToEnable() -> Bool {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = L10n.enableAlertTitle
        alert.informativeText = L10n.enableAlertMessage
        alert.addButton(withTitle: L10n.enableAlertConfirm)
        alert.addButton(withTitle: L10n.enableAlertCancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc func toggleLoginItem() {
        if loginItem.state == .requiresApproval {
            loginItem.openSystemSettings()
            syncMenuState()
            return
        }
        do {
            try loginItem.setEnabled(loginItem.state != .enabled)
            loginItemFailed = false
        } catch {
            loginItemFailed = true
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        syncMenuState()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func syncMenuState() {
        overlayItem.state = preferences.overlayEnabled ? .on : .off
        loginMenuItem.state = loginItem.state == .enabled ? .on : .off
        if loginItemFailed {
            loginMenuItem.title = L10n.launchAtLoginFailed
        } else if loginItem.state == .requiresApproval {
            loginMenuItem.title = L10n.launchAtLoginNeedsApproval
        } else {
            loginMenuItem.title = L10n.launchAtLogin
        }
    }
}
