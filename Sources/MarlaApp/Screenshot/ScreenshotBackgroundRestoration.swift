import AppKit
import Foundation
import MarlaCore

struct RestoredScreenshotBlock {
    let block: InPlaceOverlayBlock
    let appearance: ScreenshotBackgroundAppearance
}

struct RestoredScreenshot {
    let image: CGImage
    let blocks: [RestoredScreenshotBlock]
    let renderedSourceBlockCount: Int
}

enum ScreenshotBackgroundRestorer {
    private static let maximumVariation: CGFloat = 0.32

    fileprivate struct RestorationCandidate {
        let block: InPlaceOverlayBlock
        let pixelRect: CGRect
        let appearance: ScreenshotBackgroundAppearance
    }

    static func restore(
        image: CGImage,
        layout: InPlaceOverlayLayout
    ) throws -> RestoredScreenshot {
        guard let surface = PixelSurface(image: image) else {
            throw ScreenshotTranslationOverlayError.renderingFailed
        }

        var accepted: [RestoredScreenshotBlock] = []
        accepted.reserveCapacity(layout.blocks.count)
        for group in stableGroups(from: layout.blocks) {
            let candidates = group.map { block in
                let pixelRect = surface.pixelRect(for: block.normalizedBounds)
                return RestorationCandidate(
                    block: block,
                    pixelRect: pixelRect,
                    appearance: block.tableCell == nil
                        ? surface.appearance(around: pixelRect)
                        : surface.tableAppearance(in: pixelRect)
                )
            }
            guard candidates.allSatisfy({ $0.appearance.variation <= maximumVariation }) else { continue }
            if candidates.allSatisfy({ $0.block.tableCell != nil }) {
                surface.eraseTableCells(candidates)
            } else {
                for candidate in candidates {
                    surface.eraseText(in: candidate.pixelRect)
                }
            }
            for candidate in candidates {
                accepted.append(
                    RestoredScreenshotBlock(block: candidate.block, appearance: candidate.appearance)
                )
            }
        }
        guard !accepted.isEmpty else {
            throw ScreenshotTranslationOverlayError.complexBackground
        }
        guard let restoredImage = surface.makeImage() else {
            throw ScreenshotTranslationOverlayError.renderingFailed
        }
        return RestoredScreenshot(
            image: restoredImage,
            blocks: accepted,
            renderedSourceBlockCount: Set(accepted.flatMap(\.block.sourceIDs)).count
        )
    }

    private static func stableGroups(from blocks: [InPlaceOverlayBlock]) -> [[InPlaceOverlayBlock]] {
        var orderedKeys: [[String]] = []
        var grouped: [[String]: [InPlaceOverlayBlock]] = [:]
        for block in blocks {
            if grouped[block.sourceGroupKey] == nil {
                orderedKeys.append(block.sourceGroupKey)
            }
            grouped[block.sourceGroupKey, default: []].append(block)
        }
        return orderedKeys.compactMap { grouped[$0] }
    }
}

private final class PixelSurface {
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    private let context: CGContext
    private let pixels: UnsafeMutablePointer<UInt8>
    private let originalPixels: [UInt8]

    init?(image: CGImage) {
        width = image.width
        height = image.height
        bytesPerRow = width * 4
        guard width > 0,
              height > 0,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                      | CGBitmapInfo.byteOrder32Big.rawValue
              ),
              let data = context.data
        else { return nil }
        self.context = context
        let mutablePixels = data.assumingMemoryBound(to: UInt8.self)
        pixels = mutablePixels
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        originalPixels = Array(
            UnsafeBufferPointer(start: mutablePixels, count: height * bytesPerRow)
        )
    }

    func pixelRect(for bounds: NormalizedRect) -> CGRect {
        CGRect(
            x: CGFloat(bounds.x) * CGFloat(width),
            y: CGFloat(bounds.y) * CGFloat(height),
            width: CGFloat(bounds.width) * CGFloat(width),
            height: CGFloat(bounds.height) * CGFloat(height)
        )
    }

    func appearance(around rect: CGRect) -> ScreenshotBackgroundAppearance {
        let colors = perimeterSamples(around: rect).map { sample in
            NSColor(
                deviceRed: CGFloat(sample.red) / 255,
                green: CGFloat(sample.green) / 255,
                blue: CGFloat(sample.blue) / 255,
                alpha: 1
            )
        }
        return ScreenshotBackgroundSampler.robustAppearance(colors: colors)
    }

    func tableAppearance(in rect: CGRect) -> ScreenshotBackgroundAppearance {
        // Renderer-derived cell edges can cross source glyphs. Use the original cell area,
        // not those edges, and require a dominant background throughout all four quadrants.
        let area = rect.insetBy(dx: min(2, rect.width / 8), dy: min(2, rect.height / 8))
        let side = 24
        var samples: [(pixel: PixelSample, quadrant: Int)] = []
        for row in 0..<side {
            for column in 0..<side {
                // Stagger the lattice so ruled lines and checkerboards cannot alias to one color.
                let fx = (Double(column) + 0.2 + Double(row % 3) * 0.25) / Double(side)
                let fy = (Double(row) + 0.2 + Double(column % 3) * 0.25) / Double(side)
                let x = Int(area.minX + area.width * CGFloat(fx))
                let y = Int(area.minY + area.height * CGFloat(fy))
                let pixel = originalRead(x: x, y: y)
                samples.append((pixel, (row < side / 2 ? 0 : 2) + (column < side / 2 ? 0 : 1)))
            }
        }
        var bins: [Int: [PixelSample]] = [:]
        for sample in samples {
            let red = Int(sample.pixel.red) / 16
            let green = Int(sample.pixel.green) / 16
            let blue = Int(sample.pixel.blue) / 16
            bins[red * 256 + green * 16 + blue, default: []].append(sample.pixel)
        }
        let largestKey = bins.keys.sorted().max { bins[$0]!.count < bins[$1]!.count }
        guard let largestKey, let dominant = PixelSample.median(bins[largestKey] ?? []) else {
            return ScreenshotBackgroundAppearance(color: .windowBackgroundColor, textColor: .labelColor, variation: 1)
        }
        let support = samples.filter { $0.pixel.distance(to: dominant) <= 0.065 }
        let coverage = Double(support.count) / Double(samples.count)
        var quadrantCounts = [0, 0, 0, 0]
        for sample in support { quadrantCounts[sample.quadrant] += 1 }
        let quadrantSize = Double(side * side / 4)
        let distributed = quadrantCounts.allSatisfy { count in
            Double(count) / quadrantSize >= 0.45
        }
        let colors = support.map { sample in
            NSColor(deviceRed: CGFloat(sample.pixel.red) / 255, green: CGFloat(sample.pixel.green) / 255,
                    blue: CGFloat(sample.pixel.blue) / 255, alpha: 1)
        }
        let appearance = ScreenshotBackgroundSampler.robustAppearance(colors: colors)
        return ScreenshotBackgroundAppearance(
            color: appearance.color, textColor: appearance.textColor,
            variation: coverage >= 0.62 && distributed ? appearance.variation : 1
        )
    }

    func eraseText(in rawRect: CGRect) {
        let expansion = max(4, min(12, Int((rawRect.height * 0.18).rounded())))
        let rawMinX = max(0, Int(floor(rawRect.minX)))
        let rawMaxX = min(width - 1, Int(ceil(rawRect.maxX)))
        var minX = max(0, rawMinX - expansion)
        var maxX = min(width - 1, rawMaxX + expansion)
        let minY = max(0, Int(floor(rawRect.minY)) - expansion)
        let maxY = min(height - 1, Int(ceil(rawRect.maxY)) + expansion)
        if minX < rawMinX,
           let separator = (minX..<rawMinX).last(where: {
               isVerticalSeparator(x: $0, minY: minY, maxY: maxY)
           }) {
            minX = separator + 1
        }
        if rawMaxX < maxX,
           let separator = ((rawMaxX + 1)...maxX).first(where: {
               isVerticalSeparator(x: $0, minY: minY, maxY: maxY)
           }) {
            maxX = separator - 1
        }
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            let left = medianSample(
                xRange: max(0, minX - 8)...max(0, minX - 2),
                y: y
            )
            let right = medianSample(
                xRange: min(width - 1, maxX + 2)...min(width - 1, maxX + 8),
                y: y
            )
            let start = left ?? right ?? verticalSample(x: minX, minY: minY, maxY: maxY)
            let end = right ?? left ?? verticalSample(x: maxX, minY: minY, maxY: maxY)
            guard let start, let end else { continue }
            let span = max(1, maxX - minX)
            for x in minX...maxX {
                let fraction = Double(x - minX) / Double(span)
                write(PixelSample.interpolate(from: start, to: end, fraction: fraction), x: x, y: y)
            }
        }
    }

    func eraseTableCells(_ candidates: [ScreenshotBackgroundRestorer.RestorationCandidate]) {
        let preservesSourceGrid = candidates.first?.block.tableCell?.preservesSourceGrid ?? true
        let rows = Dictionary(grouping: candidates) { $0.block.tableCell?.row ?? 0 }
        for row in rows.keys.sorted() {
            guard let candidates = rows[row] else { continue }
            let rowAppearance = ScreenshotBackgroundSampler.robustAppearance(
                colors: candidates.map(\.appearance.color)
            )
            for candidate in candidates {
                fillInterior(
                    of: candidate.pixelRect,
                    color: rowAppearance.color,
                    inset: preservesSourceGrid ? 2 : 0
                )
            }
        }
    }

    func makeImage() -> CGImage? { context.makeImage() }

    private func perimeterSamples(around rect: CGRect) -> [PixelSample] {
        let minX = clampedX(Int(floor(rect.minX)))
        let maxX = clampedX(Int(ceil(rect.maxX)))
        let minY = clampedY(Int(floor(rect.minY)))
        let maxY = clampedY(Int(ceil(rect.maxY)))
        let topY = clampedY(maxY + 4)
        let bottomY = clampedY(minY - 4)
        let leftX = clampedX(minX - 4)
        let rightX = clampedX(maxX + 4)
        let xStep = max(1, (maxX - minX) / 12)
        let yStep = max(1, (maxY - minY) / 12)
        var samples: [PixelSample] = []
        for x in stride(from: minX, through: maxX, by: xStep) {
            samples.append(read(x: x, y: bottomY))
            samples.append(read(x: x, y: topY))
        }
        for y in stride(from: minY, through: maxY, by: yStep) {
            samples.append(read(x: leftX, y: y))
            samples.append(read(x: rightX, y: y))
        }
        return samples
    }

    private func medianSample(xRange: ClosedRange<Int>, y: Int) -> PixelSample? {
        let lower = clampedX(xRange.lowerBound)
        let upper = clampedX(xRange.upperBound)
        guard lower <= upper else { return nil }
        return PixelSample.median((lower...upper).map { read(x: $0, y: clampedY(y)) })
    }

    private func verticalSample(x: Int, minY: Int, maxY: Int) -> PixelSample? {
        let candidates = [minY - 6, minY - 4, maxY + 4, maxY + 6]
            .map { read(x: clampedX(x), y: clampedY($0)) }
        return PixelSample.median(candidates)
    }

    private func isVerticalSeparator(x: Int, minY: Int, maxY: Int) -> Bool {
        guard x >= 2, x <= width - 3 else { return false }
        let sampleYs = [minY - 8, minY - 4, maxY + 4, maxY + 8]
            .map(clampedY)
            .uniqued()
        guard sampleYs.count >= 2,
              let center = PixelSample.median(sampleYs.map { originalRead(x: x, y: $0) }),
              let left = PixelSample.median(sampleYs.map { originalRead(x: x - 2, y: $0) }),
              let right = PixelSample.median(sampleYs.map { originalRead(x: x + 2, y: $0) })
        else { return false }

        let centerIsContinuous = sampleYs.allSatisfy {
            originalRead(x: x, y: $0).distance(to: center) < 0.045
        }
        return centerIsContinuous
            && center.distance(to: left) > 0.055
            && center.distance(to: right) > 0.055
    }

    private func read(x: Int, y: Int) -> PixelSample {
        let offset = clampedY(y) * bytesPerRow + clampedX(x) * 4
        return PixelSample(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2],
            alpha: pixels[offset + 3]
        )
    }

    private func originalRead(x: Int, y: Int) -> PixelSample {
        let offset = clampedY(y) * bytesPerRow + clampedX(x) * 4
        return PixelSample(
            red: originalPixels[offset],
            green: originalPixels[offset + 1],
            blue: originalPixels[offset + 2],
            alpha: originalPixels[offset + 3]
        )
    }

    private func fillInterior(of rawRect: CGRect, color: NSColor, inset: CGFloat) {
        guard let converted = color.usingColorSpace(.deviceRGB) else { return }
        let fillRect = rawRect.insetBy(dx: inset, dy: inset)
        let minX = max(0, Int(ceil(fillRect.minX)))
        let maxX = min(width - 1, Int(floor(fillRect.maxX)))
        let minY = max(0, Int(ceil(fillRect.minY)))
        let maxY = min(height - 1, Int(floor(fillRect.maxY)))
        guard minX <= maxX, minY <= maxY else { return }
        let sample = PixelSample(
            red: UInt8(clamping: Int((converted.redComponent * 255).rounded())),
            green: UInt8(clamping: Int((converted.greenComponent * 255).rounded())),
            blue: UInt8(clamping: Int((converted.blueComponent * 255).rounded())),
            alpha: 255
        )
        for y in minY...maxY {
            for x in minX...maxX {
                write(sample, x: x, y: y)
            }
        }
    }

    private func write(_ sample: PixelSample, x: Int, y: Int) {
        let offset = clampedY(y) * bytesPerRow + clampedX(x) * 4
        pixels[offset] = sample.red
        pixels[offset + 1] = sample.green
        pixels[offset + 2] = sample.blue
        pixels[offset + 3] = sample.alpha
    }

    private func clampedX(_ x: Int) -> Int { min(max(x, 0), width - 1) }
    private func clampedY(_ y: Int) -> Int { min(max(y, 0), height - 1) }
}

private struct PixelSample {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    static func median(_ samples: [PixelSample]) -> PixelSample? {
        guard !samples.isEmpty else { return nil }
        return PixelSample(
            red: componentMedian(samples.map(\.red)),
            green: componentMedian(samples.map(\.green)),
            blue: componentMedian(samples.map(\.blue)),
            alpha: componentMedian(samples.map(\.alpha))
        )
    }

    static func interpolate(from start: PixelSample, to end: PixelSample, fraction: Double) -> PixelSample {
        PixelSample(
            red: interpolate(start.red, end.red, fraction: fraction),
            green: interpolate(start.green, end.green, fraction: fraction),
            blue: interpolate(start.blue, end.blue, fraction: fraction),
            alpha: interpolate(start.alpha, end.alpha, fraction: fraction)
        )
    }

    func distance(to other: PixelSample) -> Double {
        let red = Double(Int(self.red) - Int(other.red)) / 255
        let green = Double(Int(self.green) - Int(other.green)) / 255
        let blue = Double(Int(self.blue) - Int(other.blue)) / 255
        return sqrt((red * red + green * green + blue * blue) / 3)
    }

    private static func componentMedian(_ values: [UInt8]) -> UInt8 {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func interpolate(_ start: UInt8, _ end: UInt8, fraction: Double) -> UInt8 {
        UInt8(clamping: Int((Double(start) + (Double(end) - Double(start)) * fraction).rounded()))
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
