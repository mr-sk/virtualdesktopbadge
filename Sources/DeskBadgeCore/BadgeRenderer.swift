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

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.55, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]
        let text = "\(number)" as NSString
        let textSize = text.size(withAttributes: attributes)
        let origin = NSPoint(x: (size - textSize.width) / 2,
                             y: (size - textSize.height) / 2)
        text.draw(at: origin, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = true   // tint follows the menu bar appearance
        return image
    }
}
