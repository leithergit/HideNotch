import AppKit

/// Draws the HideNotch glyph in code: a screen outline, a solid top bar spanning
/// the full width, and a notch protruding down from the bar's center — meaning
/// "the notch blends into a black menu bar". Used for both the menu bar icon and
/// the app icon so the two never drift out of sync.
@MainActor
public enum NotchIcon {
    /// Fractions of the glyph rect that shape the outline/bar/notch. Tuned for
    /// legibility at 18 pt; a laptop-ish aspect keeps the shape readable at small sizes.
    enum GlyphLayout {
        /// Height of the glyph rect as a fraction of its width (a 16×12 pt laptop-ish aspect).
        static let heightFraction: CGFloat = 12.0 / 16.0
        /// Screen-outline stroke width, as a fraction of the glyph rect's height.
        static let lineWidthFraction: CGFloat = 0.10
        /// Corner radius of the screen outline and the bar's top corners, as a fraction of height.
        static let cornerRadiusFraction: CGFloat = 0.20
        /// Height of the solid top bar, as a fraction of the glyph rect's height.
        static let barHeightFraction: CGFloat = 0.34
        /// Width of the notch, as a fraction of the glyph rect's width.
        static let notchWidthFraction: CGFloat = 0.36
        /// How far the notch protrudes below the bar, as a fraction of the glyph rect's height.
        static let notchDepthFraction: CGFloat = 0.18
        /// Corner radius of the notch's bottom corners, as a fraction of the glyph rect's height.
        static let notchCornerRadiusFraction: CGFloat = 0.05
    }

    /// Fractions describing how the glyph sits on the app icon's rounded-square canvas.
    enum AppIconLayout {
        /// Square inset from the canvas edge, as a fraction of the canvas side (100/1024).
        static let squareInsetFraction: CGFloat = 100.0 / 1024.0
        /// Corner radius of the rounded square, as a fraction of the canvas side (185/1024).
        static let squareCornerRadiusFraction: CGFloat = 185.0 / 1024.0
        /// Glyph width as a fraction of the square's width.
        static let glyphWidthFraction: CGFloat = 0.6
    }

    /// An 18×18 pt template image for the status item; auto-tints for light/dark menu bars.
    public static func menuBarImage() -> NSImage {
        let canvas = NSRect(x: 0, y: 0, width: 18, height: 18)
        let image = NSImage(size: canvas.size, flipped: false) { rect in
            let glyph = glyphRect(width: 16, centeredIn: rect)
            drawGlyph(in: glyph, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "HideNotch"
        return image
    }

    /// Renders the app icon (rounded square, light gradient, centered glyph) into an
    /// exactly `pixels`×`pixels` bitmap and returns it as PNG data.
    public static func appIconPNG(pixels: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawAppIcon(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else {
            preconditionFailure("Failed to encode AppIcon PNG")
        }
        return png
    }

    /// The rect for the glyph with the given `width` (height follows the fixed aspect
    /// ratio), centered inside `container`.
    static func glyphRect(width: CGFloat, centeredIn container: CGRect) -> CGRect {
        let height = width * GlyphLayout.heightFraction
        return CGRect(
            x: container.midX - width / 2,
            y: container.midY - height / 2,
            width: width,
            height: height
        )
    }

    /// Draws the rounded square background (light vertical gradient) and the glyph on top.
    private static func drawAppIcon(in canvas: CGRect) {
        let side = canvas.width
        let inset = side * AppIconLayout.squareInsetFraction
        let square = canvas.insetBy(dx: inset, dy: inset)
        let cornerRadius = side * AppIconLayout.squareCornerRadiusFraction
        let squarePath = NSBezierPath(roundedRect: square, xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.saveGraphicsState()
        squarePath.addClip()
        let gradient = NSGradient(starting: .white, ending: NSColor(red: 0xE5 / 255, green: 0xE5 / 255, blue: 0xEA / 255, alpha: 1))!
        gradient.draw(in: square, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        let glyph = glyphRect(width: square.width * AppIconLayout.glyphWidthFraction, centeredIn: square)
        drawGlyph(in: glyph, color: .black)
    }

    /// Draws the screen outline, top bar, and notch into `rect`, in `color`.
    /// `rect` uses a bottom-left origin, y-up coordinate system (standard AppKit drawing space).
    static func drawGlyph(in rect: CGRect, color: NSColor) {
        let lineWidth = rect.height * GlyphLayout.lineWidthFraction
        let cornerRadius = rect.height * GlyphLayout.cornerRadiusFraction
        let outlineRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

        color.setStroke()
        let outline = NSBezierPath(roundedRect: outlineRect, xRadius: cornerRadius, yRadius: cornerRadius)
        outline.lineWidth = lineWidth
        outline.stroke()

        color.setFill()
        barAndNotchPath(in: outlineRect, cornerRadius: cornerRadius).fill()
    }

    /// The solid shape combining the top bar (full width, rounded top corners matching
    /// the outline) with a notch protruding down from its center (rounded bottom corners).
    private static func barAndNotchPath(in rect: CGRect, cornerRadius: CGFloat) -> NSBezierPath {
        let barHeight = rect.height * GlyphLayout.barHeightFraction
        let barBottomY = rect.maxY - barHeight
        let notchWidth = rect.width * GlyphLayout.notchWidthFraction
        let notchHalfWidth = notchWidth / 2
        let notchDepth = rect.height * GlyphLayout.notchDepthFraction
        let notchCornerRadius = rect.height * GlyphLayout.notchCornerRadiusFraction
        let notchBottomY = barBottomY - notchDepth

        // Clockwise from the bar's top-left corner, stepping down into the notch and back up.
        let points: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: barBottomY),
            CGPoint(x: rect.midX + notchHalfWidth, y: barBottomY),
            CGPoint(x: rect.midX + notchHalfWidth, y: notchBottomY),
            CGPoint(x: rect.midX - notchHalfWidth, y: notchBottomY),
            CGPoint(x: rect.midX - notchHalfWidth, y: barBottomY),
            CGPoint(x: rect.minX, y: barBottomY),
        ]
        let radii: [CGFloat] = [
            cornerRadius, cornerRadius, 0, 0, notchCornerRadius, notchCornerRadius, 0, 0,
        ]

        let cgPath = CGMutablePath()
        cgPath.move(to: points[points.count - 1])
        for i in 0..<points.count {
            cgPath.addArc(
                tangent1End: points[i], tangent2End: points[(i + 1) % points.count], radius: radii[i])
        }
        cgPath.closeSubpath()
        return NSBezierPath(cgPath: cgPath)
    }
}
