use std::ffi::{CStr, c_char};

pub const API_VERSION: u32 = 1;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum Surface {
    Unknown = 0,
    Terminal = 1,
    CodeEditor = 2,
    Browser = 3,
    Document = 4,
    Email = 5,
    Chat = 6,
    FileManager = 7,
}

pub fn classify_surface(bundle_id: &str) -> Surface {
    let normalized = bundle_id.to_ascii_lowercase();

    if contains_any(
        &normalized,
        &["terminal", "iterm", "warp", "wezterm", "alacritty"],
    ) {
        Surface::Terminal
    } else if contains_any(
        &normalized,
        &["xcode", "vscode", "visual-studio-code", "zed", "jetbrains"],
    ) {
        Surface::CodeEditor
    } else if contains_any(
        &normalized,
        &["safari", "chrome", "firefox", "arc", "browser"],
    ) {
        Surface::Browser
    } else if contains_any(&normalized, &["mail", "outlook", "airmail"]) {
        Surface::Email
    } else if contains_any(
        &normalized,
        &["messages", "telegram", "discord", "slack", "wechat"],
    ) {
        Surface::Chat
    } else if normalized == "com.apple.finder" {
        Surface::FileManager
    } else if contains_any(
        &normalized,
        &["pages", "word", "preview", "textedit", "notion", "obsidian"],
    ) {
        Surface::Document
    } else {
        Surface::Unknown
    }
}

fn contains_any(value: &str, candidates: &[&str]) -> bool {
    candidates.iter().any(|candidate| value.contains(candidate))
}

#[unsafe(no_mangle)]
pub extern "C" fn marla_core_api_version() -> u32 {
    API_VERSION
}

/// Classifies a UTF-8, null-terminated application Bundle ID.
///
/// A null pointer or invalid UTF-8 safely degrades to `Surface::Unknown`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn marla_core_classify_surface(bundle_id: *const c_char) -> u32 {
    if bundle_id.is_null() {
        return Surface::Unknown as u32;
    }

    // SAFETY: The caller contract requires a readable null-terminated string. Swift's
    // `withCString` supplies that for the duration of this synchronous call.
    let bundle_id = unsafe { CStr::from_ptr(bundle_id) };
    let Ok(bundle_id) = bundle_id.to_str() else {
        return Surface::Unknown as u32;
    };

    classify_surface(bundle_id) as u32
}

#[cfg(test)]
mod tests {
    use super::{Surface, classify_surface};

    #[test]
    fn classifies_representative_application_bundle_ids() {
        assert_eq!(classify_surface("com.apple.Terminal"), Surface::Terminal);
        assert_eq!(
            classify_surface("com.microsoft.VSCode"),
            Surface::CodeEditor
        );
        assert_eq!(classify_surface("com.apple.Safari"), Surface::Browser);
        assert_eq!(classify_surface("com.apple.finder"), Surface::FileManager);
    }

    #[test]
    fn unknown_application_degrades_safely() {
        assert_eq!(
            classify_surface("com.example.MarlaFixture"),
            Surface::Unknown
        );
    }
}
