import AppKit
import Foundation
import MarlaCore
import SwiftUI
import Vision

@MainActor
protocol VisionOCRProviding: AnyObject {
    func recognize(_ image: CGImage) async throws -> OCRDocument
}

enum VisionOCRConfiguration {
    static let productRecognitionLanguages = [
        "zh-Hans",
        "en-US",
        "ja-JP",
        "fr-FR",
        "es-ES",
        "de-DE",
        "ko-KR"
    ]

    static func availableRecognitionLanguages(from supportedLanguages: [String]) -> [String] {
        let supported = Set(supportedLanguages)
        return productRecognitionLanguages.filter(supported.contains)
    }

    static func configure(_ request: VNRecognizeTextRequest) {
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? []
        let availableLanguages = availableRecognitionLanguages(from: supportedLanguages)
        if !availableLanguages.isEmpty {
            request.recognitionLanguages = availableLanguages
        }
    }
}

@MainActor
final class VisionOCRService: VisionOCRProviding {
    func recognize(_ image: CGImage) async throws -> OCRDocument {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    VisionOCRConfiguration.configure(request)
                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { observation -> (text: String, bounds: CGRect, confidence: Double)? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return (candidate.string, observation.boundingBox, Double(candidate.confidence))
                    }.sorted { lhs, rhs in
                        let yDistance = abs(lhs.1.midY - rhs.1.midY)
                        if yDistance < 0.025 { return lhs.1.minX < rhs.1.minX }
                        return lhs.1.midY > rhs.1.midY
                    }
                    let blocks = lines.enumerated().map { index, line in
                        ContentBlock(
                            id: String(format: "line-%04d", index),
                            kind: .paragraph,
                            sourceText: line.text,
                            bounds: NormalizedRect(
                                x: line.bounds.minX,
                                y: line.bounds.minY,
                                width: line.bounds.width,
                                height: line.bounds.height
                            ),
                            readingOrder: index,
                            confidence: line.confidence
                        )
                    }
                    let document = OCRDocument(blocks: blocks)
                    guard !document.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw ScreenshotError.captureFailed
                    }
                    continuation.resume(returning: document)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
