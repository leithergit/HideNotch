import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")
    private static let loginTitle = "开机自启"

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: "黑色菜单栏", action: #selector(toggleOverlay), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: StatusItemController.loginTitle, action: #selector(toggleLoginItem), keyEquivalent: "")

    public init(preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        super.init()

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
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
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "HideNotch")
        item.menu = menu
        statusItem = item
    }

    public func menuWillOpen(_ menu: NSMenu) {
        syncMenuState()
    }

    @objc func toggleOverlay() {
        preferences.overlayEnabled.toggle()
        overlay.isEnabled = preferences.overlayEnabled
        syncMenuState()
    }

    @objc func toggleLoginItem() {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
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
        loginMenuItem.state = loginItem.isEnabled ? .on : .off
        loginMenuItem.title = loginItemFailed ? "\(Self.loginTitle)（失败）" : Self.loginTitle
    }
}
