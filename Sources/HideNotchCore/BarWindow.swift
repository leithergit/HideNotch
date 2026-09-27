import AppKit

@MainActor
public protocol BarWindowHosting: AnyObject {
    var frame: CGRect { get }
    func show(at rect: CGRect)
    func hide()
}

public final class BarWindow: NSWindow, BarWindowHosting {
    /// One below the system menu bar so menu titles and status items draw on top.
    public static let barLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)

    public init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = true
        // Other apps' Cmd-Opt-H "Hide Others" must not hide the bar permanently.
        canHide = false
        isReleasedWhenClosed = false
        level = Self.barLevel
        // No .fullScreenAuxiliary: the bar must not appear in full-screen spaces.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    /// AppKit otherwise pushes the window below the menu bar, over app title bars.
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public func show(at rect: CGRect) {
        setFrame(rect, display: true)
        orderFrontRegardless()
    }

    public func hide() {
        orderOut(nil)
    }
}
