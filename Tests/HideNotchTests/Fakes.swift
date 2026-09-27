import CoreGraphics
@testable import HideNotchCore

@MainActor
final class FakeScreens: ScreenProviding {
    var list: [ScreenMetrics] = []
    func currentScreens() -> [ScreenMetrics] { list }
}

@MainActor
final class FakeWindow: BarWindowHosting {
    var frame: CGRect = .zero
    var isShown = false
    func show(at rect: CGRect) { frame = rect; isShown = true }
    func hide() { isShown = false }
}

@MainActor
final class WindowFactory {
    var made: [FakeWindow] = []
    func make() -> BarWindowHosting {
        let window = FakeWindow()
        made.append(window)
        return window
    }
}

enum Screens {
    static let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
        visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130),
        safeAreaTop: 38)
    static let external = ScreenMetrics(
        frame: CGRect(x: 1800, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1800, y: 0, width: 1920, height: 1055),
        safeAreaTop: 0)
}
