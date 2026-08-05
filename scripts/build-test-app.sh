#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
derived_data=${MARLA_XCODE_DERIVED_DATA:-/private/tmp/marla-xcode-test-app}
artifact_directory=${MARLA_ARTIFACT_DIRECTORY:-${project_root}/artifacts}

export DEVELOPER_DIR="${developer_directory}"

build_settings=$(
    /usr/bin/xcodebuild \
        -project "${project_root}/Marla.xcodeproj" \
        -scheme Marla \
        -configuration Release \
        -derivedDataPath "${derived_data}" \
        -destination 'platform=macOS,arch=arm64' \
        -showBuildSettings
)

if ! print -r -- "${build_settings}" | rg -q "LIBRARY_SEARCH_PATHS = .*${project_root}/target/release"; then
    print -u2 "Release does not resolve the Rust library from target/release."
    exit 1
fi

if print -r -- "${build_settings}" | rg -q 'LIBRARY_SEARCH_PATHS = .*target/debug'; then
    print -u2 "Release unexpectedly references a debug Rust library path."
    exit 1
fi

/usr/bin/xcodebuild \
    -project "${project_root}/Marla.xcodeproj" \
    -scheme Marla \
    -configuration Release \
    -derivedDataPath "${derived_data}" \
    -destination 'platform=macOS,arch=arm64' \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= \
    build

source_app="${derived_data}/Build/Products/Release/Marla.app"
if [[ ! -d ${source_app} ]]; then
    print -u2 "Release build did not produce ${source_app}."
    exit 1
fi

mkdir -p "${artifact_directory}"
timestamp=$(TZ=Asia/Shanghai /bin/date +%Y%m%d%H%M)
artifact_path="${artifact_directory}/Marla_test_${timestamp}.app"

if [[ -e ${artifact_path} ]]; then
    print -u2 "Refusing to overwrite existing artifact: ${artifact_path}"
    exit 1
fi

/usr/bin/ditto --norsrc "${source_app}" "${artifact_path}"
"${script_directory}/verify-app.sh" "${artifact_path}"

print "Artifact ready: ${artifact_path}"
