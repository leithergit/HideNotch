import CoreGraphics
import Testing
@testable import HideNotchCore

@MainActor
struct OverlayControllerTests {
    let screens = FakeScreens()
    let factory = WindowFactory()

    func makeController() -> OverlayController {
        OverlayController(screens: screens, makeWindow: factory.make)
    }

    @Test func newControllerIsDisabled() {
        screens.list = [Screens.notched]
        let controller = makeController()
        #expect(!controller.isEnabled)
        #expect(factory.made.isEmpty)
    }

    @Test func enablingShowsBarOnNotchedScreenOnly() {
        screens.list = [Screens.notched, Screens.external]
        let controller = makeController()
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
        #expect(factory.made[0].isShown)
        #expect(factory.made[0].frame == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func refreshWhileDisabledCreatesNothing() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.refresh()
        #expect(factory.made.isEmpty)
    }

    @Test func refreshMovesExistingWindow() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        var resized = Screens.notched
        resized.frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        resized.visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        resized.safeAreaTop = 32
        screens.list = [resized]
        controller.refresh()
        #expect(factory.made.count == 1)
        #expect(factory.made[0].frame == CGRect(x: 0, y: 945, width: 1512, height: 37))
    }

    @Test func refreshRemovesWindowWhenScreenGone() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        screens.list = [Screens.external]
        controller.refresh()
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func disablingHidesAll() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        controller.isEnabled = false
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func repeatedRefreshIsIdempotent() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        for _ in 0..<5 { controller.refresh() }
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
    }

    @Test func reEnableReusesSlots() {
        screens.list = [Screens.notched]
        let controller = makeController()
        for _ in 0..<3 {
            controller.isEnabled = true
            controller.isEnabled = false
        }
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.filter(\.isShown).count == 1)
    }
}
