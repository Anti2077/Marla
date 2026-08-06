#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
derived_data=${MARLA_XCODE_DERIVED_DATA:-/private/tmp/marla-xcode-test-app}
artifact_directory=${MARLA_ARTIFACT_DIRECTORY:-${project_root}/artifacts}
requested_artifact_path=${MARLA_ARTIFACT_PATH:-}

export DEVELOPER_DIR="${developer_directory}"

if [[ ${artifact_directory} != /* ]]; then
    artifact_directory="${project_root}/${artifact_directory}"
fi
artifact_directory=${artifact_directory:A}
default_artifact_path="${artifact_directory}/Marla_dev.app"

if [[ -n ${requested_artifact_path} ]]; then
    artifact_path=${requested_artifact_path}
    if [[ ${artifact_path} != /* ]]; then
        artifact_path="${project_root}/${artifact_path}"
    fi
    artifact_path=${artifact_path:A}
else
    artifact_path=${default_artifact_path}
fi

if [[ ${artifact_path} != *.app || ${artifact_path} == / || ${artifact_path} == ${project_root} ]]; then
    print -u2 "Artifact path must be a specific .app bundle: ${artifact_path}"
    exit 1
fi

if [[ -e ${artifact_path} && ${artifact_path} != ${default_artifact_path} && ${MARLA_ALLOW_ARTIFACT_REPLACE:-0} != 1 ]]; then
    print -u2 "Refusing to overwrite existing custom artifact: ${artifact_path}"
    print -u2 "Set MARLA_ALLOW_ARTIFACT_REPLACE=1 only when that exact custom path may be replaced."
    exit 1
fi

reuse_existing_requirement=0
expected_requirement=
if [[ -n ${MARLA_CODE_SIGN_IDENTITY+x} ]]; then
    signing_identity=${MARLA_CODE_SIGN_IDENTITY}
    if [[ -z ${signing_identity} || ${signing_identity} == - ]]; then
        print -u2 "MARLA_CODE_SIGN_IDENTITY must name a stable code-signing identity; ad-hoc signing is not allowed."
        exit 1
    fi
else
    if [[ ! -d ${default_artifact_path} ]]; then
        print -u2 "No existing ${default_artifact_path} is available to supply a stable signing identity."
        print -u2 "For the first build, set MARLA_CODE_SIGN_IDENTITY to a valid identity from: security find-identity -v -p codesigning"
        exit 1
    fi

    expected_requirement=$(
        /usr/bin/codesign --display --requirements - "${default_artifact_path}" 2>&1 |
            rg '^designated => ' |
            head -n 1
    )
    signing_identity=$(
        print -r -- "${expected_requirement}" |
            /usr/bin/sed -E 's/.*certificate (leaf|root) = H"([[:xdigit:]]{40})".*/\2/' |
            /usr/bin/tr '[:lower:]' '[:upper:]'
    )

    if [[ -z ${expected_requirement} || ${signing_identity} == ${expected_requirement} || ${#signing_identity} -ne 40 ]]; then
        print -u2 "Could not recover a stable certificate hash from ${default_artifact_path}."
        print -u2 "Set MARLA_CODE_SIGN_IDENTITY explicitly to a valid code-signing identity."
        exit 1
    fi
    reuse_existing_requirement=1
fi

available_identities=$(/usr/bin/security find-identity -v -p codesigning)
if ! print -r -- "${available_identities}" | rg -F -i -q -- "${signing_identity}"; then
    print -u2 "Stable code-signing identity is unavailable or not trusted: ${signing_identity}"
    print -u2 "Check the login keychain with: security find-identity -v -p codesigning"
    exit 1
fi

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

artifact_parent=${artifact_path:h}
mkdir -p "${artifact_parent}"
staging_directory=$(/usr/bin/mktemp -d "${artifact_parent}/.marla-build.XXXXXX")
staged_app="${staging_directory}/Marla.app"

cleanup() {
    if [[ -d ${staging_directory} ]]; then
        /bin/rm -rf "${staging_directory}"
    fi
}
trap cleanup EXIT INT TERM

/usr/bin/ditto --norsrc "${source_app}" "${staged_app}"
/usr/bin/codesign --force --deep --sign "${signing_identity}" --timestamp=none "${staged_app}"
"${script_directory}/verify-app.sh" "${staged_app}"

staged_requirement=$(
    /usr/bin/codesign --display --requirements - "${staged_app}" 2>&1 |
        rg '^designated => ' |
        head -n 1
)
if (( reuse_existing_requirement )) && [[ ${staged_requirement} != ${expected_requirement} ]]; then
    print -u2 "The staged App's designated requirement changed; keeping the existing artifact untouched."
    print -u2 "Expected: ${expected_requirement}"
    print -u2 "Actual:   ${staged_requirement}"
    exit 1
fi

if [[ -e ${artifact_path} ]]; then
    /bin/rm -rf "${artifact_path}"
fi
/bin/mv "${staged_app}" "${artifact_path}"
"${script_directory}/verify-app.sh" "${artifact_path}"

final_requirement=$(
    /usr/bin/codesign --display --requirements - "${artifact_path}" 2>&1 |
        rg '^designated => ' |
        head -n 1
)
if (( reuse_existing_requirement )) && [[ ${final_requirement} != ${expected_requirement} ]]; then
    print -u2 "The installed App's designated requirement does not match the previous stable identity."
    exit 1
fi

print "Artifact ready: ${artifact_path}"
print "Designated requirement: ${final_requirement}"
