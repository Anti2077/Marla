#!/bin/zsh

set -euo pipefail

if (( $# != 1 )); then
    print -u2 "Usage: ./scripts/verify-app.sh /path/to/Marla.app"
    exit 64
fi

app_path=${1:A}
info_plist="${app_path}/Contents/Info.plist"
resources_path="${app_path}/Contents/Resources"

if [[ ! -d ${app_path} ]]; then
    print -u2 "App bundle does not exist: ${app_path}"
    exit 1
fi

if [[ ! -f ${info_plist} ]]; then
    print -u2 "Info.plist is missing: ${info_plist}"
    exit 1
fi

read_plist_value() {
    /usr/bin/plutil -extract "$1" raw -o - "${info_plist}"
}

require_value() {
    local label=$1
    local actual=$2
    local expected=$3

    if [[ ${actual} != ${expected} ]]; then
        print -u2 "${label} mismatch: expected '${expected}', got '${actual}'."
        exit 1
    fi
}

bundle_id=$(read_plist_value CFBundleIdentifier)
version=$(read_plist_value CFBundleShortVersionString)
minimum_system=$(read_plist_value LSMinimumSystemVersion)
agent_app=$(read_plist_value LSUIElement)
executable_name=$(read_plist_value CFBundleExecutable)
executable_path="${app_path}/Contents/MacOS/${executable_name}"
icon_name=$(read_plist_value CFBundleIconName)
icon_file=$(read_plist_value CFBundleIconFile)

require_value "Bundle identifier" "${bundle_id}" "com.marla.app"
require_value "Marketing version" "${version}" "0.1.0"
require_value "Minimum system" "${minimum_system}" "14.0"
require_value "LSUIElement" "${agent_app}" "true"
require_value "App icon name" "${icon_name}" "AppIcon"
require_value "App icon file" "${icon_file}" "AppIcon"

icon_path="${resources_path}/AppIcon.icns"
asset_catalog_path="${resources_path}/Assets.car"
if [[ ! -s ${icon_path} ]]; then
    print -u2 "Compiled Paper Lantern icon is missing or empty: ${icon_path}"
    exit 1
fi
if [[ ! -s ${asset_catalog_path} ]]; then
    print -u2 "Compiled asset catalog is missing or empty: ${asset_catalog_path}"
    exit 1
fi

asset_info=$(DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" /usr/bin/xcrun assetutil --info "${asset_catalog_path}")
paper_lantern_renditions=(
    paper-lantern-16.png
    paper-lantern-16@2x.png
    paper-lantern-32.png
    paper-lantern-32@2x.png
    paper-lantern-128.png
    paper-lantern-128@2x.png
    paper-lantern-256.png
    paper-lantern-256@2x.png
    paper-lantern-512.png
    paper-lantern-512@2x.png
)
for rendition in "${paper_lantern_renditions[@]}"; do
    if ! print -r -- "${asset_info}" | rg -F -q -- "\"RenditionName\" : \"${rendition}\""; then
        print -u2 "Compiled asset catalog is missing Paper Lantern rendition: ${rendition}"
        exit 1
    fi
done

status_bar_renditions=(
    status-bar-icon.png
    status-bar-icon@2x.png
)
for rendition in "${status_bar_renditions[@]}"; do
    if ! print -r -- "${asset_info}" | rg -F -q -- "\"RenditionName\" : \"${rendition}\""; then
        print -u2 "Compiled asset catalog is missing Paper Lantern status-bar rendition: ${rendition}"
        exit 1
    fi
done

menu_brand_renditions=(
    paper-lantern-mark.png
    paper-lantern-mark@2x.png
)
for rendition in "${menu_brand_renditions[@]}"; do
    if ! print -r -- "${asset_info}" | rg -F -q -- "\"RenditionName\" : \"${rendition}\""; then
        print -u2 "Compiled asset catalog is missing Paper Lantern menu-brand rendition: ${rendition}"
        exit 1
    fi
done

if [[ ! -x ${executable_path} ]]; then
    print -u2 "App executable is missing or not executable: ${executable_path}"
    exit 1
fi

architectures=$(/usr/bin/lipo -archs "${executable_path}")
require_value "Executable architecture" "${architectures}" "arm64"

developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
build_metadata=$(DEVELOPER_DIR="${developer_directory}" /usr/bin/xcrun vtool -show-build "${executable_path}")
if ! print -r -- "${build_metadata}" | rg -q 'minos 14\.0'; then
    print -u2 "Executable does not declare macOS 14.0 as its minimum system."
    exit 1
fi

/usr/bin/codesign --verify --deep --strict "${app_path}"
signing_details=$(/usr/bin/codesign --display --verbose=2 "${app_path}" 2>&1)
if ! print -r -- "${signing_details}" | rg -q '^Identifier=com\.marla\.app$'; then
    print -u2 "Code signature identifier is not com.marla.app."
    exit 1
fi
signature_summary=$(print -r -- "${signing_details}" | rg '^(Authority|Signature)=' | head -n 1 || true)
if [[ -z ${signature_summary} ]]; then
    signature_summary="signature details unavailable"
fi

print "Verified app: ${app_path}"
print "  Bundle ID: ${bundle_id}"
print "  Version: ${version}"
print "  Minimum macOS: ${minimum_system}"
print "  Architecture: ${architectures}"
print "  App icon: ${icon_name} (Paper Lantern, ${#paper_lantern_renditions} renditions)"
print "  Status-bar icon: Paper Lantern template (${#status_bar_renditions} renditions)"
print "  Menu brand mark: Paper Lantern color mark (${#menu_brand_renditions} renditions)"
print "  Signing: valid (${signature_summary})"
