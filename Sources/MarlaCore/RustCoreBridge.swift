import Foundation

#if !MARLA_XCODE_APP
import MarlaRustFFI
#endif

public enum RustCoreBridge {
    public static var apiVersion: UInt32 {
        marla_core_api_version()
    }

    public static func classifySurface(applicationBundleID: String) -> SurfaceType {
        let rawValue = applicationBundleID.withCString { bundleID in
            marla_core_classify_surface(bundleID)
        }

        switch rawValue {
        case 1:
            return .terminal
        case 2:
            return .codeEditor
        case 3:
            return .browser
        case 4:
            return .document
        case 5:
            return .email
        case 6:
            return .chat
        case 7:
            return .fileManager
        default:
            return .unknown
        }
    }
}

public final class RustTranslationClient: @unchecked Sendable {
    public final class Handle: @unchecked Sendable {
        private var rawHandle: OpaquePointer?
        private let context: UnsafeMutableRawPointer
        private let lock = NSLock()

        fileprivate init(rawHandle: OpaquePointer, context: UnsafeMutableRawPointer) {
            self.rawHandle = rawHandle
            self.context = context
        }

        public func cancel() {
            lock.lock()
            defer { lock.unlock() }
            guard let rawHandle else { return }
            marla_translation_cancel(rawHandle)
        }

        public func release() {
            lock.lock()
            guard let rawHandle else {
                lock.unlock()
                return
            }
            self.rawHandle = nil
            marla_translation_release(rawHandle)
            lock.unlock()
            Unmanaged<CallbackBox>.fromOpaque(context).release()
        }

        deinit {
            release()
        }
    }

    private final class CallbackBox: @unchecked Sendable {
        let callback: @Sendable (TranslationFFIEvent) -> Void

        init(callback: @escaping @Sendable (TranslationFFIEvent) -> Void) {
            self.callback = callback
        }
    }

    public init() {}

    @discardableResult
    public func start(
        request: TranslationFFIRequest,
        onEvent: @escaping @Sendable (TranslationFFIEvent) -> Void
    ) throws -> Handle {
        let data = try JSONEncoder().encode(request)
        let box = CallbackBox(callback: onEvent)
        let opaqueContext = Unmanaged.passRetained(box).toOpaque()
        let callback: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafeMutableRawPointer?) -> Void = { bytes, length, context in
            guard let bytes, length > 0, let context else { return }
            let copy = Data(bytes: bytes, count: length)
            guard let event = try? JSONDecoder().decode(TranslationFFIEvent.self, from: copy) else { return }
            TranslationCallbackMetrics.record(event)
            Unmanaged<CallbackBox>.fromOpaque(context).takeUnretainedValue().callback(event)
        }
        let rawHandle = data.withUnsafeBytes { buffer in
            marla_translation_start(
                buffer.bindMemory(to: UInt8.self).baseAddress,
                data.count,
                callback,
                opaqueContext
            )
        }
        guard let rawHandle else {
            Unmanaged<CallbackBox>.fromOpaque(opaqueContext).release()
            throw RustTranslationError.startFailed
        }
        return Handle(rawHandle: rawHandle, context: opaqueContext)
    }
}

public final class RustModelListClient: @unchecked Sendable {
    public final class Handle: @unchecked Sendable {
        private var rawHandle: OpaquePointer?
        private let context: UnsafeMutableRawPointer
        private let lock = NSLock()

        fileprivate init(rawHandle: OpaquePointer, context: UnsafeMutableRawPointer) {
            self.rawHandle = rawHandle
            self.context = context
        }

        public func cancel() {
            lock.lock()
            defer { lock.unlock() }
            guard let rawHandle else { return }
            marla_translation_cancel(rawHandle)
        }

        public func release() {
            lock.lock()
            guard let rawHandle else {
                lock.unlock()
                return
            }
            self.rawHandle = nil
            marla_translation_release(rawHandle)
            lock.unlock()
            Unmanaged<CallbackBox>.fromOpaque(context).release()
        }

        deinit {
            release()
        }
    }

    private final class CallbackBox: @unchecked Sendable {
        let callback: @Sendable (ModelListFFIEvent) -> Void

        init(callback: @escaping @Sendable (ModelListFFIEvent) -> Void) {
            self.callback = callback
        }
    }

    public init() {}

    @discardableResult
    public func start(
        request: ModelListFFIRequest,
        onEvent: @escaping @Sendable (ModelListFFIEvent) -> Void
    ) throws -> Handle {
        let data = try JSONEncoder().encode(request)
        let box = CallbackBox(callback: onEvent)
        let opaqueContext = Unmanaged.passRetained(box).toOpaque()
        let callback: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafeMutableRawPointer?) -> Void = { bytes, length, context in
            guard let bytes, length > 0, let context else { return }
            let copy = Data(bytes: bytes, count: length)
            guard let event = try? JSONDecoder().decode(ModelListFFIEvent.self, from: copy) else { return }
            Unmanaged<CallbackBox>.fromOpaque(context).takeUnretainedValue().callback(event)
        }
        let rawHandle = data.withUnsafeBytes { buffer in
            marla_model_list_start(
                buffer.bindMemory(to: UInt8.self).baseAddress,
                data.count,
                callback,
                opaqueContext
            )
        }
        guard let rawHandle else {
            Unmanaged<CallbackBox>.fromOpaque(opaqueContext).release()
            throw RustTranslationError.startFailed
        }
        return Handle(rawHandle: rawHandle, context: opaqueContext)
    }
}

public final class RustOCRClient: @unchecked Sendable {
    public final class Handle: @unchecked Sendable {
        private var rawHandle: OpaquePointer?
        private let context: UnsafeMutableRawPointer
        private let lock = NSLock()

        fileprivate init(rawHandle: OpaquePointer, context: UnsafeMutableRawPointer) {
            self.rawHandle = rawHandle
            self.context = context
        }

        public func cancel() {
            lock.lock()
            defer { lock.unlock() }
            guard let rawHandle else { return }
            marla_translation_cancel(rawHandle)
        }

        public func release() {
            lock.lock()
            guard let rawHandle else {
                lock.unlock()
                return
            }
            self.rawHandle = nil
            marla_translation_release(rawHandle)
            lock.unlock()
            Unmanaged<CallbackBox>.fromOpaque(context).release()
        }

        deinit { release() }
    }

    private final class CallbackBox: @unchecked Sendable {
        let callback: @Sendable (OCRFFIEvent) -> Void

        init(callback: @escaping @Sendable (OCRFFIEvent) -> Void) {
            self.callback = callback
        }
    }

    public init() {}

    @discardableResult
    public func start(
        request: OCRFFIRequest,
        onEvent: @escaping @Sendable (OCRFFIEvent) -> Void
    ) throws -> Handle {
        let data = try JSONEncoder().encode(request)
        let box = CallbackBox(callback: onEvent)
        let opaqueContext = Unmanaged.passRetained(box).toOpaque()
        let callback: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafeMutableRawPointer?) -> Void = { bytes, length, context in
            guard let bytes, length > 0, let context else { return }
            let copy = Data(bytes: bytes, count: length)
            guard let event = try? JSONDecoder().decode(OCRFFIEvent.self, from: copy) else { return }
            Unmanaged<CallbackBox>.fromOpaque(context).takeUnretainedValue().callback(event)
        }
        let rawHandle = data.withUnsafeBytes { buffer in
            marla_ocr_start(
                buffer.bindMemory(to: UInt8.self).baseAddress,
                data.count,
                callback,
                opaqueContext
            )
        }
        guard let rawHandle else {
            Unmanaged<CallbackBox>.fromOpaque(opaqueContext).release()
            throw RustTranslationError.startFailed
        }
        return Handle(rawHandle: rawHandle, context: opaqueContext)
    }
}

public enum RustTranslationError: LocalizedError, Equatable, Sendable {
    case startFailed

    public var errorDescription: String? {
        "无法启动翻译请求。"
    }
}
