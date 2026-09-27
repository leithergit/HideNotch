import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct BarWindowTests {
    @Test func keepsRequestedFrameOverMenuBar() {
        // 回归：AppKit 默认会把窗口挪到菜单栏下方，压住应用标题栏
        let window = BarWindow()
        let rect = NSRect(x: 0, y: 1130, width: 1800, height: 39)
        #expect(window.constrainFrameRect(rect, to: NSScreen.main) == rect)
    }

    @Test func sitsJustBelowMenuBarLevel() {
        #expect(BarWindow().level.rawValue == NSWindow.Level.mainMenu.rawValue - 1)
    }

    @Test func isOpaqueBlackAndClickThrough() {
        let window = BarWindow()
        #expect(window.backgroundColor == .black)
        #expect(window.isOpaque)
        #expect(!window.hasShadow)
        #expect(window.ignoresMouseEvents)
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func joinsAllSpacesButNotFullScreen() {
        let behavior = BarWindow().collectionBehavior
        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.stationary))
        #expect(behavior.contains(.ignoresCycle))
        #expect(!behavior.contains(.fullScreenAuxiliary))
    }

    @Test func showMovesAndHideOrdersOut() {
        let window = BarWindow()
        let rect = CGRect(x: 0, y: 1130, width: 1800, height: 39)
        window.show(at: rect)
        #expect(window.frame == rect)
        #expect(window.isVisible)
        window.hide()
        #expect(!window.isVisible)
    }
}
