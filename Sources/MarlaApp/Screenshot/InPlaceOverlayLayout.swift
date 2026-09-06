import AppKit
import Foundation
import MarlaCore

enum InPlaceOverlayLayoutError: LocalizedError, Equatable {
    case invalidCanvas
    case mismatchedBlockIDs
    case noRenderableBlocks

    var errorDescription: String? {
        switch self {
        case .invalidCanvas:
            "截图区域尺寸无效。"
        case .mismatchedBlockIDs:
            "块级译文与 OCR 布局不一致。"
        case .noRenderableBlocks:
            "GLM-OCR 没有返回可可靠原位排版的文字块。"
        }
    }
}

struct InPlaceOverlayBlock: Equatable {
    let id: String
    let sourceIDs: [String]
    let kind: ContentBlockKind
    let text: String
    let normalizedBounds: NormalizedRect
    let sourceFrame: CGRect
    let frame: CGRect
    let fontSize: CGFloat
    let fontWeight: NSFont.Weight
    let usesMonospacedFont: Bool
    let tableCell: InPlaceOverlayTableCell?
    let attributedText: NSAttributedString?

    init(
        id: String,
        sourceIDs: [String] = [],
        kind: ContentBlockKind,
        text: String,
        normalizedBounds: NormalizedRect,
        sourceFrame: CGRect,
        frame: CGRect,
        fontSize: CGFloat,
        fontWeight: NSFont.Weight,
        usesMonospacedFont: Bool,
        tableCell: InPlaceOverlayTableCell? = nil,
        attributedText: NSAttributedString? = nil
    ) {
        self.id = id
        self.sourceIDs = sourceIDs.isEmpty ? [id] : sourceIDs
        self.kind = kind
        self.text = text
        self.normalizedBounds = normalizedBounds
        self.sourceFrame = sourceFrame
        self.frame = frame
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.usesMonospacedFont = usesMonospacedFont
        self.tableCell = tableCell
        self.attributedText = attributedText
    }

    var sourceGroupKey: [String] { sourceIDs }
}

struct InPlaceOverlayLayout: Equatable {
    let canvasSize: CGSize
    let blocks: [InPlaceOverlayBlock]
    let sourceBlockCount: Int

    var renderedSourceBlockCount: Int { Set(blocks.flatMap(\.sourceIDs)).count }
    var omittedBlockCount: Int { sourceBlockCount - renderedSourceBlockCount }
}

@MainActor
enum InPlaceOverlayLayoutBuilder {
    private static let minimumDimension: CGFloat = 3
    private static let minimumFontSize: CGFloat = 8
    private static let horizontalAllowance: CGFloat = 1.5
    private static let verticalAllowance: CGFloat = 2
    private static let tableHorizontalInset: CGFloat = 6
    private static let tableVerticalInset: CGFloat = 3
    private static let tablePreferredFontSize: CGFloat = 13

    static func make(
        document: OCRDocument,
        translation: InPlaceTranslationResult,
        canvasSize: CGSize
    ) throws -> InPlaceOverlayLayout {
        guard canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              canvasSize.width > 0,
              canvasSize.height > 0
        else { throw InPlaceOverlayLayoutError.invalidCanvas }

        let sourceIDs = document.blocks.map(\.id)
        let translatedIDs = translation.blocks.map(\.id)
        guard Set(sourceIDs).count == sourceIDs.count,
              Set(translatedIDs).count == translatedIDs.count,
              Set(sourceIDs) == Set(translatedIDs)
        else { throw InPlaceOverlayLayoutError.mismatchedBlockIDs }

        var planned: [InPlaceOverlayBlock] = []
        planned.reserveCapacity(document.blocks.count)
        for unit in InPlaceTableGrouping.units(document: document, translation: translation) {
            switch unit.content {
            case .omitted:
                continue
            case let .table(sourceIDs, sourceMarkdown, translatedMarkdown, bounds, preservesSourceGrid):
                let sourceFrame = frame(for: bounds, canvasSize: canvasSize)
                guard sourceFrame.width >= minimumDimension,
                      sourceFrame.height >= minimumDimension,
                      let translatedTable = InPlaceMarkdownProjection.table(from: translatedMarkdown),
                      let tableBlocks = tableBlocks(
                          id: sourceIDs[0],
                          sourceIDs: sourceIDs,
                          sourceMarkdown: sourceMarkdown,
                          translatedTable: translatedTable,
                          sourceFrame: preservesSourceGrid
                              ? sourceFrame
                              : renderingFrame(for: sourceFrame, canvasSize: canvasSize),
                          canvasSize: canvasSize,
                          preservesSourceGrid: preservesSourceGrid
                      )
                else { continue }
                planned.append(contentsOf: tableBlocks)
            case let .single(source, rawTranslatedText):
                guard let bounds = source.bounds else { continue }
                guard bounds.x.isFinite,
                      bounds.y.isFinite,
                      bounds.width.isFinite,
                      bounds.height.isFinite,
                      bounds.x >= 0,
                      bounds.y >= 0,
                      bounds.width > 0,
                      bounds.height > 0,
                      bounds.x + bounds.width <= 1,
                      bounds.y + bounds.height <= 1
                else { continue }
                let sourceFrame = frame(for: bounds, canvasSize: canvasSize)
                guard sourceFrame.width >= minimumDimension,
                      sourceFrame.height >= minimumDimension
                else { continue }
                let translatedText = rawTranslatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !translatedText.isEmpty else {
                    throw InPlaceOverlayLayoutError.mismatchedBlockIDs
                }

                let frame = renderingFrame(for: sourceFrame, canvasSize: canvasSize)
                let style = style(for: source.kind, frame: frame)
                guard let fitted = fittingAttributedText(
                    markdown: translatedText,
                    frame: frame.insetBy(dx: 2, dy: 1),
                    style: style
                ) else { continue }

                planned.append(
                    InPlaceOverlayBlock(
                        id: source.id,
                        kind: source.kind,
                        text: fitted.attributedText.string,
                        normalizedBounds: bounds,
                        sourceFrame: sourceFrame,
                        frame: frame,
                        fontSize: fitted.fontSize,
                        fontWeight: style.weight,
                        usesMonospacedFont: style.monospaced,
                        attributedText: fitted.attributedText
                    )
                )
            }
        }
        let accepted = removingSevereOverlaps(from: planned)
        guard !accepted.isEmpty else { throw InPlaceOverlayLayoutError.noRenderableBlocks }
        return InPlaceOverlayLayout(
            canvasSize: canvasSize,
            blocks: accepted,
            sourceBlockCount: document.blocks.count
        )
    }

    static func frame(for bounds: NormalizedRect, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(bounds.x) * canvasSize.width,
            y: CGFloat(1 - bounds.y - bounds.height) * canvasSize.height,
            width: CGFloat(bounds.width) * canvasSize.width,
            height: CGFloat(bounds.height) * canvasSize.height
        )
    }

    private static func renderingFrame(for sourceFrame: CGRect, canvasSize: CGSize) -> CGRect {
        sourceFrame
            .insetBy(dx: -horizontalAllowance, dy: -verticalAllowance)
            .intersection(CGRect(origin: .zero, size: canvasSize))
    }

    private struct TextStyle {
        let preferredSize: CGFloat
        let weight: NSFont.Weight
        let monospaced: Bool
    }

    private static func tableBlocks(
        id: String,
        sourceIDs: [String],
        sourceMarkdown: String,
        translatedTable: InPlaceMarkdownTable,
        sourceFrame: CGRect,
        canvasSize: CGSize,
        preservesSourceGrid: Bool
    ) -> [InPlaceOverlayBlock]? {
        let rowCount = translatedTable.rows.count
        guard rowCount > 0,
              let columnCount = translatedTable.rows.first?.count,
              columnCount > 0
        else { return nil }

        let sourceTable = InPlaceMarkdownProjection.table(from: sourceMarkdown)
        if let sourceTable,
           (sourceTable.rows.count != rowCount || sourceTable.rows.first?.count != columnCount) {
            return nil
        }

        let tables = [sourceTable, translatedTable].compactMap { $0 }
        let columnWidths = tableColumnWidths(
            tables: tables,
            totalWidth: sourceFrame.width,
            columnCount: columnCount
        )
        guard columnWidths.count == columnCount else { return nil }

        var fontSize = min(tablePreferredFontSize, max(minimumFontSize, floor(sourceFrame.height / CGFloat(rowCount) / 1.18)))
        var rowHeights: [CGFloat]?
        while fontSize >= minimumFontSize {
            let required = requiredTableRowHeights(
                rows: translatedTable.rows,
                columnWidths: columnWidths,
                fontSize: fontSize
            )
            if required.reduce(0, +) <= sourceFrame.height {
                let scale = sourceFrame.height / max(1, required.reduce(0, +))
                rowHeights = required.map { $0 * scale }
                break
            }
            fontSize -= 0.5
        }
        guard let rowHeights else { return nil }

        var blocks: [InPlaceOverlayBlock] = []
        blocks.reserveCapacity(rowCount * columnCount)
        var top = sourceFrame.maxY
        for row in 0..<rowCount {
            let rowHeight = row == rowCount - 1 ? top - sourceFrame.minY : rowHeights[row]
            var left = sourceFrame.minX
            for column in 0..<columnCount {
                let columnWidth = column == columnCount - 1 ? sourceFrame.maxX - left : columnWidths[column]
                let cellFrame = CGRect(
                    x: left,
                    y: top - rowHeight,
                    width: columnWidth,
                    height: rowHeight
                )
                let alignment = if row == 0 || column == 0 {
                    InPlaceOverlayTextAlignment.center
                } else {
                    translatedTable.alignments[column]
                }
                let contentFrame = cellFrame.insetBy(dx: tableHorizontalInset, dy: tableVerticalInset)
                let weight: NSFont.Weight = row == 0 ? .semibold : .regular
                guard contentFrame.width > 0,
                      contentFrame.height > 0,
                      let attributedText = tableCellAttributedText(
                          translatedTable.rows[row][column],
                          fontSize: fontSize,
                          weight: weight,
                          alignment: alignment,
                          forceBold: row == 0
                      ),
                      attributedTextFits(attributedText, frame: contentFrame)
                else { return nil }
                blocks.append(
                    InPlaceOverlayBlock(
                        id: id,
                        sourceIDs: sourceIDs,
                        kind: .table,
                        text: attributedText.string,
                        normalizedBounds: normalizedBounds(for: cellFrame, canvasSize: canvasSize),
                        sourceFrame: cellFrame,
                        frame: cellFrame,
                        fontSize: fontSize,
                        fontWeight: weight,
                        usesMonospacedFont: false,
                        tableCell: InPlaceOverlayTableCell(
                            row: row,
                            column: column,
                            rowCount: rowCount,
                            columnCount: columnCount,
                            alignment: alignment,
                            preservesSourceGrid: preservesSourceGrid
                        ),
                        attributedText: attributedText
                    )
                )
                left += columnWidth
            }
            top -= rowHeight
        }
        return blocks
    }

    private static func tableColumnWidths(
        tables: [InPlaceMarkdownTable],
        totalWidth: CGFloat,
        columnCount: Int
    ) -> [CGFloat] {
        guard columnCount > 0, totalWidth > 0 else { return [] }
        let measuringFont = NSFont.systemFont(ofSize: tablePreferredFontSize)
        var measured = Array(repeating: CGFloat(24), count: columnCount)
        for table in tables {
            for row in table.rows {
                for column in 0..<min(columnCount, row.count) {
                    let visibleText = String(row[column].characters)
                    let width = (visibleText as NSString).size(withAttributes: [.font: measuringFont]).width
                    measured[column] = max(measured[column], width + tableHorizontalInset * 2)
                }
            }
        }
        let weights = measured.map { sqrt(max(1, $0)) }
        let weightTotal = max(1, weights.reduce(0, +))
        return weights.map { totalWidth * $0 / weightTotal }
    }

    private static func requiredTableRowHeights(
        rows: [[AttributedString]],
        columnWidths: [CGFloat],
        fontSize: CGFloat
    ) -> [CGFloat] {
        rows.enumerated().map { row, cells in
            let weight: NSFont.Weight = row == 0 ? .semibold : .regular
            let contentHeight = cells.enumerated().map { column, content in
                let width = max(1, columnWidths[column] - tableHorizontalInset * 2)
                let alignment = column == 0 ? InPlaceOverlayTextAlignment.center : .leading
                let attributed = tableCellAttributedText(
                    content,
                    fontSize: fontSize,
                    weight: weight,
                    alignment: alignment,
                    forceBold: row == 0
                )
                return attributed.map {
                    InPlaceMarkdownAttributedText.measuredSize($0, width: width).height
                } ?? .greatestFiniteMagnitude
            }.max() ?? ceil(fontSize * 1.2)
            return contentHeight + tableVerticalInset * 2
        }
    }

    private static func tableCellAttributedText(
        _ content: AttributedString,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        alignment: InPlaceOverlayTextAlignment,
        forceBold: Bool
    ) -> NSAttributedString? {
        guard fontSize > 0 else { return nil }
        return InPlaceMarkdownAttributedText.buildCell(
            content,
            configuration: .init(
                baseFontSize: fontSize,
                baseWeight: weight,
                usesMonospacedFont: false,
                alignment: alignment.appKitValue
            ),
            forceBold: forceBold
        )
    }

    private static func attributedTextFits(
        _ attributedText: NSAttributedString,
        frame: CGRect
    ) -> Bool {
        let measured = InPlaceMarkdownAttributedText.measuredSize(attributedText, width: frame.width)
        return measured.width <= ceil(frame.width) && measured.height <= ceil(frame.height)
    }

    private static func normalizedBounds(for frame: CGRect, canvasSize: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: Double(frame.minX / canvasSize.width),
            y: Double(1 - frame.maxY / canvasSize.height),
            width: Double(frame.width / canvasSize.width),
            height: Double(frame.height / canvasSize.height)
        )
    }

    private static func style(for kind: ContentBlockKind, frame: CGRect) -> TextStyle {
        let style: TextStyle
        switch kind {
        case .title:
            style = TextStyle(preferredSize: 30, weight: .bold, monospaced: false)
        case .heading:
            style = TextStyle(preferredSize: 23, weight: .semibold, monospaced: false)
        case .paragraph:
            style = TextStyle(preferredSize: 16, weight: .regular, monospaced: false)
        case .listItem:
            style = TextStyle(preferredSize: 15, weight: .regular, monospaced: false)
        case .table:
            style = TextStyle(preferredSize: 13, weight: .regular, monospaced: false)
        case .code:
            style = TextStyle(preferredSize: 14, weight: .regular, monospaced: true)
        case .formula:
            style = TextStyle(preferredSize: 15, weight: .medium, monospaced: false)
        case .caption:
            style = TextStyle(preferredSize: 12, weight: .regular, monospaced: false)
        case .other:
            style = TextStyle(preferredSize: 14, weight: .regular, monospaced: false)
        }
        let heightBound = max(minimumFontSize, floor(frame.height / 1.18))
        return TextStyle(
            preferredSize: min(style.preferredSize, heightBound),
            weight: style.weight,
            monospaced: style.monospaced
        )
    }

    private struct FittedAttributedText {
        let fontSize: CGFloat
        let attributedText: NSAttributedString
    }

    private static func fittingAttributedText(
        markdown: String,
        frame: CGRect,
        style: TextStyle
    ) -> FittedAttributedText? {
        guard frame.width > 0, frame.height > 0 else { return nil }
        var size = style.preferredSize
        while size >= minimumFontSize {
            if let attributedText = InPlaceMarkdownAttributedText.build(
                markdown: markdown,
                configuration: .init(
                    baseFontSize: size,
                    baseWeight: style.weight,
                    usesMonospacedFont: style.monospaced,
                    alignment: .left
                )
            ), attributedText.length > 0,
               attributedTextFits(attributedText, frame: frame) {
                return FittedAttributedText(fontSize: size, attributedText: attributedText)
            }
            size -= 0.5
        }
        return nil
    }

    private static func removingSevereOverlaps(from blocks: [InPlaceOverlayBlock]) -> [InPlaceOverlayBlock] {
        let groups = stableGroups(from: blocks)
        guard groups.count > 1 else { return blocks }
        let priorityOrder = groups.indices.sorted { left, right in
            let leftArea = groups[left].frame.width * groups[left].frame.height
            let rightArea = groups[right].frame.width * groups[right].frame.height
            return leftArea == rightArea ? left < right : leftArea < rightArea
        }
        var acceptedIndices: [Int] = []
        for index in priorityOrder {
            let candidate = groups[index]
            let conflicts = acceptedIndices.contains { acceptedIndex in
                severelyOverlaps(candidate.frame, groups[acceptedIndex].frame)
            }
            if !conflicts {
                acceptedIndices.append(index)
            }
        }
        let acceptedKeys = Set(acceptedIndices.map { groups[$0].key })
        return blocks.filter { acceptedKeys.contains($0.sourceGroupKey) }
    }

    private struct BlockGroup {
        let key: [String]
        let frame: CGRect
    }

    private static func stableGroups(from blocks: [InPlaceOverlayBlock]) -> [BlockGroup] {
        var orderedKeys: [[String]] = []
        var frames: [[String]: CGRect] = [:]
        for block in blocks {
            if let frame = frames[block.sourceGroupKey] {
                frames[block.sourceGroupKey] = frame.union(block.sourceFrame)
            } else {
                orderedKeys.append(block.sourceGroupKey)
                frames[block.sourceGroupKey] = block.sourceFrame
            }
        }
        return orderedKeys.compactMap { key in
            frames[key].map { BlockGroup(key: key, frame: $0) }
        }
    }

    private static func severelyOverlaps(_ left: CGRect, _ right: CGRect) -> Bool {
        let intersection = left.intersection(right)
        guard !intersection.isNull, !intersection.isEmpty else { return false }
        let smallerArea = min(left.width * left.height, right.width * right.height)
        guard smallerArea > 0 else { return false }
        return (intersection.width * intersection.height) / smallerArea > 0.35
    }
}
