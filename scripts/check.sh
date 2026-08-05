#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cache_root=${MARLA_BUILD_CACHE_ROOT:-/private/tmp/marla-build-cache}

mkdir -p "${cache_root}/clang" "${cache_root}/swiftpm"

export DEVELOPER_DIR="${developer_directory}"
export CLANG_MODULE_CACHE_PATH="${cache_root}/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${cache_root}/swiftpm"

cd "${project_root}"

cargo fmt --all --check
cargo test --workspace
cargo build --workspace
swift build --disable-sandbox
swift test --disable-sandbox

source_paths=(.gitignore AGENTS.md Cargo.toml Package.swift README.md Sources Tests docs rust scripts)
if rg -n '[[:blank:]]+$' "${source_paths[@]}"; then
    print -u2 "Trailing whitespace found."
    exit 1
fi

git diff --check
