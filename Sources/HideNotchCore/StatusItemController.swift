import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")
    private static let loginTitle = "开机自启"

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private let confirmEnable: @MainActor () -> Bool
    private var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: "隐藏刘海", action: #selector(toggleOverlay), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: StatusItemController.loginTitle, action: #selector(toggleLoginItem), keyEquivalent: "")

    public init(
        preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling,
        confirmEnable: @escaping @MainActor () -> Bool = StatusItemController.askToEnable
    ) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        self.confirmEnable = confirmEnable
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
        alert.messageText = "隐藏刘海"
        alert.informativeText = "将把带刘海屏幕的菜单栏背景变成黑色，与刘海融为一体。"
        alert.addButton(withTitle: "开启")
        alert.addButton(withTitle: "取消")
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
            loginMenuItem.title = "\(Self.loginTitle)（失败）"
        } else if loginItem.state == .requiresApproval {
            loginMenuItem.title = "\(Self.loginTitle)（需在系统设置中批准）"
        } else {
            loginMenuItem.title = Self.loginTitle
        }
    }
}
