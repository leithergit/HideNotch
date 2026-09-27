import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct StatusItemControllerTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"
    let screens = FakeScreens()
    let factory = WindowFactory()
    let login = FakeLoginItem()

    func makeSUT(overlayEnabled: Bool = true) -> (StatusItemController, Preferences, OverlayController) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let prefs = Preferences(defaults: defaults)
        prefs.overlayEnabled = overlayEnabled
        screens.list = [Screens.notched]
        let overlay = OverlayController(screens: screens, makeWindow: factory.make)
        overlay.isEnabled = prefs.overlayEnabled
        let sut = StatusItemController(preferences: prefs, overlay: overlay, loginItem: login)
        return (sut, prefs, overlay)
    }

    @Test func menuHasToggleLoginAndQuit() {
        let (sut, _, _) = makeSUT()
        #expect(sut.menu.items.map(\.title) == ["黑色菜单栏", "开机自启", "", "退出"])
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
    }

    @Test func toggleLoginItemEnables() {
        let (sut, _, _) = makeSUT()
        sut.toggleLoginItem()
        #expect(login.state == .enabled)
        #expect(sut.loginMenuItem.state == .on)
        #expect(sut.loginMenuItem.title == "开机自启")
    }

    @Test func loginItemFailureIsShown() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        #expect(login.state == .disabled)
        #expect(sut.loginMenuItem.state == .off)
        #expect(sut.loginMenuItem.title == "开机自启（失败）")
    }

    @Test func loginItemSuccessClearsFailure() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        login.shouldFail = false
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == "开机自启")
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
        #expect(sut.loginMenuItem.title == "开机自启（需在系统设置中批准）")
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
        #expect(sut.loginMenuItem.title == "开机自启（需在系统设置中批准）")
    }
}
