#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cache_root=${MARLA_BUILD_CACHE_ROOT:-/private/tmp/marla-build-cache}

mkdir -p "${cache_root}/clang" "${cache_root}/swiftpm" "${cache_root}/xcode"

export DEVELOPER_DIR="${developer_directory}"
export CLANG_MODULE_CACHE_PATH="${cache_root}/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${cache_root}/swiftpm"

cd "${project_root}"

local_state_path=.marla/worktree-state.md
if ! rg -Fxq '/.marla/worktree-state.md' .gitignore; then
    print -u2 "${local_state_path} must have an exact repository ignore rule."
    exit 1
fi
if ! git check-ignore -q -- "${local_state_path}"; then
    print -u2 "${local_state_path} must be ignored by Git."
    exit 1
fi
if git ls-files --error-unmatch "${local_state_path}" >/dev/null 2>&1; then
    print -u2 "${local_state_path} is local coordination state and must not be tracked."
    exit 1
fi

cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo build --workspace
./scripts/check-structure.sh
for script in scripts/*.sh; do
    /bin/zsh -n "${script}"
done
swift build --disable-sandbox
swift test --disable-sandbox
/usr/bin/xcodebuild \
    -project Marla.xcodeproj \
    -scheme Marla \
    -configuration Debug \
    -derivedDataPath "${cache_root}/xcode" \
    -destination 'platform=macOS,arch=arm64' \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEBUG MARLA_CHECK_BUILD' \
    CODE_SIGNING_ALLOWED=NO \
    build

source_paths=(.cargo .gitignore AGENTS.md Cargo.toml Package.swift README.md Marla.xcodeproj Resources Sources Tests docs rust scripts)
if rg -n '[[:blank:]]+$' "${source_paths[@]}"; then
    print -u2 "Trailing whitespace found."
    exit 1
fi

git diff --check
