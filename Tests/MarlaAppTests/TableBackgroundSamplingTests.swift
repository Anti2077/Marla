import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

@MainActor
final class TableBackgroundSamplingTests: XCTestCase {
    func testGlyphsAcrossDerivedCellPerimeterDoNotRejectSimpleBackground() throws {
        for dark in [false, true] {
            let image = try makeImage { context in
                context.setFillColor(CGColor(gray: dark ? 0.08 : 0.97, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 240, height: 120))
                context.setFillColor(CGColor(gray: dark ? 0.94 : 0.05, alpha: 1))
                for x in stride(from: 42, to: 188, by: 12) {
                    context.fill(CGRect(x: x, y: 22, width: 10, height: 13))
                    context.fill(CGRect(x: x, y: 87, width: 10, height: 13))
                }
            }
            let originalBackground = try XCTUnwrap(NSBitmapImageRep(cgImage: image).colorAt(x: 120, y: 60)?.usingColorSpace(.deviceRGB))
            for shift in [-2.0, 0, 2] {
                let result = try ScreenshotBackgroundRestorer.restore(image: image, layout: layout(shift: shift))
                XCTAssertEqual(result.renderedSourceBlockCount, 1)
                XCTAssertEqual(result.blocks.count, 1)
                let color = try XCTUnwrap(result.blocks.first?.appearance.color.usingColorSpace(.deviceRGB))
                XCTAssertEqual(color.redComponent, originalBackground.redComponent, accuracy: 0.015)
            }
        }
    }

    func testDenseCheckerboardCannotAliasToSafeBackground() throws {
        for offset in 0..<4 {
            let image = try makeImage { context in
                for y in stride(from: -4, to: 124, by: 4) {
                    for x in stride(from: -4, to: 244, by: 4) {
                        context.setFillColor(CGColor(gray: ((x + y) / 4).isMultiple(of: 2) ? 0.1 : 0.95, alpha: 1))
                        context.fill(CGRect(x: x + offset, y: y + offset, width: 4, height: 4))
                    }
                }
            }
            XCTAssertThrowsError(try ScreenshotBackgroundRestorer.restore(image: image, layout: layout()))
        }
    }

    func testBroadGradientStillRejectsWholeTable() throws {
        let image = try makeImage { context in
            for x in 0..<240 {
                context.setFillColor(CGColor(gray: CGFloat(x) / 240, alpha: 1))
                context.fill(CGRect(x: x, y: 0, width: 1, height: 120))
            }
        }
        XCTAssertThrowsError(try ScreenshotBackgroundRestorer.restore(image: image, layout: layout()))
    }

    func testOneComplexQuadrantCannotHideBehindMajorityBackground() throws {
        let image = try makeImage { context in
            context.setFillColor(CGColor(gray: 0.98, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 120))
            context.setFillColor(CGColor(gray: 0.08, alpha: 1))
            context.fill(CGRect(x: 50, y: 30, width: 65, height: 30))
        }
        XCTAssertThrowsError(try ScreenshotBackgroundRestorer.restore(image: image, layout: layout()))
    }

    private func layout(shift: Double = 0) -> InPlaceOverlayLayout {
        let rect = CGRect(x: 50 + shift, y: 30 + shift, width: 130, height: 60)
        let block = InPlaceOverlayBlock(
            id: "table", kind: .table, text: "Result",
            normalizedBounds: .init(x: rect.minX / 240, y: rect.minY / 120, width: 130.0 / 240, height: 0.5),
            sourceFrame: rect, frame: rect, fontSize: 12, fontWeight: .regular, usesMonospacedFont: false,
            tableCell: .init(row: 0, column: 0, rowCount: 1, columnCount: 1, alignment: .leading)
        )
        return InPlaceOverlayLayout(canvasSize: CGSize(width: 240, height: 120), blocks: [block], sourceBlockCount: 1)
    }

    private func makeImage(_ draw: (CGContext) -> Void) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        draw(context)
        return try XCTUnwrap(context.makeImage())
    }
}
