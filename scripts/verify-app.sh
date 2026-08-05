#!/bin/zsh

set -euo pipefail

if (( $# != 1 )); then
    print -u2 "Usage: ./scripts/verify-app.sh /path/to/Marla.app"
    exit 64
fi

app_path=${1:A}
info_plist="${app_path}/Contents/Info.plist"

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

require_value "Bundle identifier" "${bundle_id}" "com.marla.app"
require_value "Marketing version" "${version}" "0.1.0"
require_value "Minimum system" "${minimum_system}" "14.0"
require_value "LSUIElement" "${agent_app}" "true"

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

print "Verified app: ${app_path}"
print "  Bundle ID: ${bundle_id}"
print "  Version: ${version}"
print "  Minimum macOS: ${minimum_system}"
print "  Architecture: ${architectures}"
print "  Signing: valid ($(print -r -- "${signing_details}" | rg '^Signature=' | head -n 1))"
