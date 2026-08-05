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
