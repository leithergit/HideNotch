import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct StatusItemControllerTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"
    let screens = FakeScreens()
    let factory = WindowFactory()
    let login = FakeLoginItem()
    let confirm = ConfirmSpy()

    func makeSUT(overlayEnabled: Bool = true) -> (StatusItemController, Preferences, OverlayController) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let prefs = Preferences(defaults: defaults)
        prefs.overlayEnabled = overlayEnabled
        screens.list = [Screens.notched]
        let overlay = OverlayController(screens: screens, makeWindow: factory.make)
        overlay.isEnabled = prefs.overlayEnabled
        let sut = StatusItemController(
            preferences: prefs, overlay: overlay, loginItem: login, confirmEnable: confirm.ask)
        return (sut, prefs, overlay)
    }

    @Test func menuHasToggleLoginAndQuit() {
        let (sut, _, _) = makeSUT()
        #expect(sut.menu.items.map(\.title) == [L10n.hideNotch, L10n.launchAtLogin, "", L10n.quit])
        #expect(sut.menu.items[2].isSeparatorItem)
    }

    @Test func menuReflectsDisabledPreference() {
        let (sut, _, overlay) = makeSUT(overlayEnabled: false)
        #expect(sut.overlayItem.state == .off)
        #expect(overlay.windows.isEmpty)
    }

    @Test func toggleOverlayUpdatesPreferenceOverlayAndMenu() {
        let (sut, prefs, overlay) = makeSUT()
        #expect(sut.overlayItem.state == .on)
        sut.toggleOverlay()
        #expect(!prefs.overlayEnabled)
        #expect(!overlay.isEnabled)
        #expect(overlay.windows.isEmpty)
        #expect(sut.overlayItem.state == .off)
        #expect(confirm.calls == 0)
    }

    @Test func enablingAsksAndCancelKeepsOff() {
        let (sut, prefs, overlay) = makeSUT(overlayEnabled: false)
        confirm.answer = false
        sut.toggleOverlay()
        #expect(confirm.calls == 1)
        #expect(!prefs.overlayEnabled)
        #expect(!overlay.isEnabled)
        #expect(overlay.windows.isEmpty)
        #expect(sut.overlayItem.state == .off)
    }

    @Test func enablingConfirmedTurnsOn() {
        let (sut, prefs, overlay) = makeSUT(overlayEnabled: false)
        confirm.answer = true
        sut.toggleOverlay()
        #expect(confirm.calls == 1)
        #expect(prefs.overlayEnabled)
        #expect(overlay.windows.count == 1)
        #expect(sut.overlayItem.state == .on)
    }

    @Test func toggleLoginItemEnables() {
        let (sut, _, _) = makeSUT()
        sut.toggleLoginItem()
        #expect(login.state == .enabled)
        #expect(sut.loginMenuItem.state == .on)
        #expect(sut.loginMenuItem.title == L10n.launchAtLogin)
    }

    @Test func loginItemFailureIsShown() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        #expect(login.state == .disabled)
        #expect(sut.loginMenuItem.state == .off)
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginFailed)
    }

    @Test func loginItemSuccessClearsFailure() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        login.shouldFail = false
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == L10n.launchAtLogin)
        #expect(sut.loginMenuItem.state == .on)
    }

    @Test func menuWillOpenResyncsExternalChanges() {
        let (sut, _, _) = makeSUT()
        login.state = .enabled  // 用户在系统设置里改了登录项
        sut.menuWillOpen(sut.menu)
        #expect(sut.loginMenuItem.state == .on)
    }

    @Test func loginItemPendingApprovalIsShown() {
        let (sut, _, _) = makeSUT()
        login.stateAfterEnable = .requiresApproval
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginNeedsApproval)
        #expect(sut.loginMenuItem.state == .off)
    }

    @Test func clickingWhilePendingOpensSettings() {
        let (sut, _, _) = makeSUT()
        login.state = .requiresApproval
        sut.toggleLoginItem()
        #expect(login.openedSettings == 1)
        #expect(login.state == .requiresApproval)
    }

    @Test func menuWillOpenShowsPendingApproval() {
        let (sut, _, _) = makeSUT()
        login.state = .requiresApproval
        sut.menuWillOpen(sut.menu)
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginNeedsApproval)
    }
}
