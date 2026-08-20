import AppKit
import CoreGraphics
import Foundation

struct EncodedOCRImage: Equatable, Sendable {
    let data: Data
    let mimeType: String
}

enum CloudOCRImageEncodingError: LocalizedError, Equatable {
    case encodingFailed
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "无法为云端结构识别编码截图。"
        case .imageTooLarge: "截图编码后仍超过 GLM-OCR 的 10 MB 限制，请缩小框选区域。"
        }
    }
}

enum CloudOCRImageEncoder {
    static let safetyLimit = 9_500_000

    static func encode(_ image: CGImage) throws -> EncodedOCRImage {
        if let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
           png.count <= safetyLimit {
            return EncodedOCRImage(data: png, mimeType: "image/png")
        }

        var candidate = image
        for _ in 0..<4 {
            guard let jpeg = NSBitmapImageRep(cgImage: candidate).representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.9]
            ) else {
                throw CloudOCRImageEncodingError.encodingFailed
            }
            if jpeg.count <= safetyLimit {
                return EncodedOCRImage(data: jpeg, mimeType: "image/jpeg")
            }
            let scale = min(0.85, sqrt(Double(safetyLimit) / Double(jpeg.count)) * 0.92)
            guard let scaled = scaledImage(candidate, scale: scale) else {
                throw CloudOCRImageEncodingError.encodingFailed
            }
            candidate = scaled
        }
        throw CloudOCRImageEncodingError.imageTooLarge
    }

    private static func scaledImage(_ image: CGImage, scale: Double) -> CGImage? {
        let width = max(1, Int(Double(image.width) * scale))
        let height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
