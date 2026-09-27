import AppKit

@MainActor
public protocol ScreenProviding {
    func currentScreens() -> [ScreenMetrics]
}

public struct SystemScreens: ScreenProviding {
    public init() {}

    public func currentScreens() -> [ScreenMetrics] {
        NSScreen.screens.map {
            ScreenMetrics(frame: $0.frame, visibleFrame: $0.visibleFrame, safeAreaTop: $0.safeAreaInsets.top)
        }
    }
}

/// Keeps one bar window per notched screen in sync with the current screen layout.
@MainActor
public final class OverlayController {
    private let screens: ScreenProviding
    private let makeWindow: @MainActor () -> BarWindowHosting
    private(set) var windows: [BarWindowHosting] = []

    public var isEnabled = false {
        didSet { refresh() }
    }

    public init(screens: ScreenProviding, makeWindow: @escaping @MainActor () -> BarWindowHosting) {
        self.screens = screens
        self.makeWindow = makeWindow
    }

    public func refresh() {
        let rects = isEnabled ? screens.currentScreens().compactMap(BarGeometry.barRect(for:)) : []
        while windows.count > rects.count {
            windows.removeLast().hide()
        }
        while windows.count < rects.count {
            windows.append(makeWindow())
        }
        for (window, rect) in zip(windows, rects) {
            window.show(at: rect)
        }
    }
}
