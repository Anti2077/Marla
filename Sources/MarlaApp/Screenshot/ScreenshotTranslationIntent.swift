import MarlaCore

enum ScreenshotTranslationIntent: Equatable {
    case nearby
    case inPlace

    func ocrProvider(configuredProvider: OCRProviderKind) -> OCRProviderKind {
        self == .inPlace ? .glmOCR : configuredProvider
    }

    var usesInPlaceOverlay: Bool { self == .inPlace }
    var presentsNearbyResultCardAfterCapture: Bool { self == .nearby }
    var presentsNearbyFailureCardBeforeCapture: Bool { self == .nearby }
    var allowsVisionFallback: Bool { self == .nearby }
}
