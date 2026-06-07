import AppKit

// Renders the DeskBadge app icon (a desktops grid with one active, numbered
// desktop) into an .iconset directory passed as the first argument.

func squircle(_ rect: NSRect, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
}

/// Draw the icon at the given pixel size into the current graphics context.
func drawIcon(_ size: CGFloat) {
    // Background squircle with a little transparent padding.
    let pad = size * 0.06
    let bgRect = NSRect(x: pad, y: pad, width: size - pad * 2, height: size - pad * 2)
    let bgPath = squircle(bgRect, (size - pad * 2) * 0.2237)
    NSGradient(starting: NSColor(calibratedWhite: 0.24, alpha: 1),
               ending: NSColor(calibratedWhite: 0.13, alpha: 1))!.draw(in: bgPath, angle: -90)

    // 3x3 grid of desktops; the center one is "active".
    let cols = 3, rows = 3
    let area = size * 0.6
    let gap = area * 0.12
    let cell = (area - gap * CGFloat(cols - 1)) / CGFloat(cols)
    let originX = size / 2 - area / 2
    let originY = size / 2 - area / 2
    let accent = NSColor(calibratedRed: 0.30, green: 0.55, blue: 1.0, alpha: 1)

    for row in 0..<rows {
        for col in 0..<cols {
            let x = originX + CGFloat(col) * (cell + gap)
            let y = originY + CGFloat(rows - 1 - row) * (cell + gap)
            let rect = NSRect(x: x, y: y, width: cell, height: cell)
            let path = squircle(rect, cell * 0.25)
            let active = (row == 1 && col == 1)
            (active ? accent : NSColor(calibratedWhite: 0.4, alpha: 1)).setFill()
            path.fill()
            if active {
                let para = NSMutableParagraphStyle()
                para.alignment = .center
                let font = NSFont.monospacedDigitSystemFont(ofSize: cell * 0.62, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] =
                    [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: para]
                let str = "5" as NSString
                let ts = str.size(withAttributes: attrs)
                str.draw(at: NSPoint(x: x + cell / 2 - ts.width / 2,
                                     y: y + cell / 2 - ts.height / 2 - font.descender / 2),
                         withAttributes: attrs)
            }
        }
    }
}

func pngData(at pixels: Int) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <output.iconset>\n".utf8))
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel size) pairs required by iconutil.
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    guard let data = pngData(at: px) else {
        FileHandle.standardError.write(Data("failed to render \(name)\n".utf8))
        exit(1)
    }
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Wrote \(entries.count) icon sizes to \(outDir)")
