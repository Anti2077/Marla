// Offline synthetic table fixture renderer. Never captures the desktop.
import AppKit
import Foundation

struct Cell: Decodable {
    let row: Int
    let col: Int
    let text: String
    let rowspan: Int
    let colspan: Int
    let header: Bool
}
struct Fixture: Decodable {
    let id: String
    let title: String
    let footer: String
    let widths: [Double]
    let rows: Int
    let dark: Bool
    let cells: [Cell]
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: input))
for fixture in fixtures {
    let rowHeight: CGFloat = 86
    let width = CGFloat(fixture.widths.reduce(0, +)) + 64
    let height = CGFloat(fixture.rows) * rowHeight + 190
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let bg = fixture.dark ? NSColor(calibratedWhite: 0.075, alpha: 1) : .white
    let fg = fixture.dark ? NSColor.white : NSColor.black
    bg.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    (fixture.title as NSString).draw(at: NSPoint(x: 32, y: height - 66), withAttributes: [
        .font: NSFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: fg
    ])
    for cell in fixture.cells {
        let x = CGFloat(fixture.widths.prefix(cell.col).reduce(0, +)) + 32
        let w = CGFloat(fixture.widths.dropFirst(cell.col).prefix(cell.colspan).reduce(0, +))
        let h = rowHeight * CGFloat(cell.rowspan)
        let y = height - 100 - rowHeight * CGFloat(cell.row) - h
        let rect = NSRect(x: x, y: y, width: w, height: h)
        let shade: CGFloat = fixture.dark ? (cell.header ? 0.23 : 0.12) : (cell.header ? 0.90 : 0.99)
        NSColor(calibratedWhite: shade, alpha: 1).setFill()
        rect.fill()
        NSColor.gray.setStroke()
        NSBezierPath(rect: rect).stroke()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 21, weight: cell.header ? .semibold : .regular),
            .foregroundColor: fg
        ]
        (cell.text as NSString).draw(in: rect.insetBy(dx: 14, dy: 12), withAttributes: attrs)
    }
    (fixture.footer as NSString).draw(in: NSRect(x: 32, y: 16, width: width - 64, height: 58), withAttributes: [
        .font: NSFont.systemFont(ofSize: 20), .foregroundColor: fg
    ])
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(fixture.id + ".png"))
    print("Rendered \(fixture.id) \(Int(width))x\(Int(height))")
}
