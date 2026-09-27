import CoreGraphics
import Testing
@testable import HideNotchCore

struct BarGeometryTests {
    // 实测值：1800x1169，菜单栏 39pt，刘海 38pt
    @Test func notchedScreenCoversMenuBar() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func screenWithoutNotchHasNoBar() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            safeAreaTop: 0)
        #expect(BarGeometry.barRect(for: m) == nil)
    }

    @Test func autoHiddenMenuBarUsesNotchHeight() {
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1131, width: 1800, height: 38))
    }

    @Test func dockDoesNotAffectBar() {
        // Dock 在底部（原点上移）且在左侧（宽度变窄）
        let m = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 70, y: 80, width: 1730, height: 1050),
            safeAreaTop: 38)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func offsetScreenKeepsGlobalCoordinates() {
        let m = ScreenMetrics(
            frame: CGRect(x: 1920, y: -200, width: 1512, height: 982),
            visibleFrame: CGRect(x: 1920, y: -200, width: 1512, height: 945),
            safeAreaTop: 32)
        #expect(BarGeometry.barRect(for: m) == CGRect(x: 1920, y: 745, width: 1512, height: 37))
    }
}
