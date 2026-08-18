import AppKit
import CoreText
import Foundation
import Vision

@main
struct RV003VisionProbe {
    static func main() throws {
        let width = 2400
        let height = 1600
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ProbeError.imageCreation }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let text = "Marla recognizes English text locally. 这是简体中文 OCR 内存样本。"
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: CTFontCreateUIFontForLanguage(.system, 54, nil)!,
                .foregroundColor: NSColor.black.cgColor
            ]
        )
        context.textPosition = CGPoint(x: 80, y: 800)
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        guard let image = context.makeImage() else { throw ProbeError.imageCreation }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let productLanguages = ["zh-Hans", "en-US", "ja-JP", "fr-FR", "es-ES", "de-DE", "ko-KR"]
        let supported = Set(try request.supportedRecognitionLanguages())
        request.recognitionLanguages = productLanguages.filter(supported.contains)
        let startedAt = ContinuousClock.now
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let elapsed = startedAt.duration(to: .now)
        let recognizedLines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        print("VISION_ELAPSED=\(elapsed)")
        print("VISION_LINES=\(recognizedLines.count)")
    }

    enum ProbeError: Error {
        case imageCreation
    }
}
