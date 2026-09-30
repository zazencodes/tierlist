// Draws the app icon, a mini tier list, as a 1024×1024 PNG: swift mac/icon.swift <out.png>
import Cocoa

let size = 1024.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

// macOS icon grid: an 824pt rounded square centered on the canvas, with a soft drop shadow.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
hex(0x1a1a1f).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: hex(0x34343d), ending: hex(0x1c1c22))!.draw(in: bodyPath, angle: -90)

// Four tier rows, like the app: a colored label square, then tiles on a panel strip.
let tiers: [(String, UInt32, [UInt32])] = [
    ("S", 0xff7f7f, [0x6c8cff, 0xb07cff]),
    ("A", 0xffbf7f, [0x4fd1a5, 0xff9f6b, 0x6c8cff]),
    ("B", 0xffdf7f, [0xe8e8ee]),
    ("C", 0xffff7f, [0xb07cff, 0x4fd1a5, 0xff9f6b]),
]
let inset = 92.0, gap = 20.0
let left = body.minX + inset, right = body.maxX - inset
let rowH = (body.height - 2 * inset - gap * Double(tiers.count - 1)) / Double(tiers.count)
let tileGap = 16.0, tilePad = 16.0
let label = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
label.alignment = .center

for (i, (name, color, tiles)) in tiers.enumerated() {
    let y = body.maxY - inset - rowH - Double(i) * (rowH + gap)
    let row = NSRect(x: left, y: y, width: right - left, height: rowH)
    let rowPath = NSBezierPath(roundedRect: row, xRadius: 24, yRadius: 24)
    hex(0x2a2a31).setFill()
    rowPath.fill()

    NSGraphicsContext.saveGraphicsState()
    rowPath.addClip()
    hex(color).setFill()
    NSRect(x: left, y: y, width: rowH, height: rowH).fill()
    NSGraphicsContext.restoreGraphicsState()

    let font = NSFont.systemFont(ofSize: rowH * 0.62, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: hex(0x1a1a1f), .paragraphStyle: label]
    let textH = font.ascender - font.descender
    (name as NSString).draw(in: NSRect(x: left, y: y + (rowH - textH) / 2 + font.descender * 0.15, width: rowH, height: textH), withAttributes: attrs)

    let tile = rowH - 2 * tilePad
    for (j, c) in tiles.enumerated() {
        let r = NSRect(x: left + rowH + tileGap + Double(j) * (tile + tileGap), y: y + tilePad, width: tile, height: tile)
        hex(c).setFill()
        NSBezierPath(roundedRect: r, xRadius: 16, yRadius: 16).fill()
    }
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
