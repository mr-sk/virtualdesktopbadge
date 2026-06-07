import AppKit

/// Renders a Space number into a small rounded-box template image.
public enum BadgeRenderer {
    public static func image(forNumber number: Int, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let inset: CGFloat = 1.5
        let boxRect = NSRect(x: inset, y: inset,
                             width: size - inset * 2, height: size - inset * 2)
        let box = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        box.lineWidth = 1.5
        NSColor.black.setStroke()
        box.stroke()

        let text = "\(number)" as NSString

        // Auto-shrink font so multi-digit numbers fit inside the box.
        let available = boxRect.width - 2
        var fontSize = size * 0.55
        var font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        var textSize = text.size(withAttributes: [.font: font])
        if textSize.width > available {
            fontSize *= available / textSize.width
            font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]
        textSize = text.size(withAttributes: attributes)

        // Use font.descender (negative) to nudge glyphs to optical center.
        let x = (size - textSize.width) / 2
        let y = (size - textSize.height) / 2 - font.descender / 2
        text.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = true   // tint follows the menu bar appearance
        return image
    }
}
