#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/native"
MOD_MODE="${HIDNET_GO_MOD_MODE:-readonly}"
case "$MOD_MODE" in
  readonly|vendor) ;;
  *) echo "HIDNET_GO_MOD_MODE must be readonly or vendor." >&2; exit 1 ;;
esac

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The iOS core requires macOS and the iOS SDK from Xcode." >&2
  exit 1
fi
command -v go >/dev/null
command -v xcodebuild >/dev/null
mkdir -p "$OUT" "$ROOT/Frameworks"

build_slice() {
  local name="$1" sdk="$2" arch="$3" target="$4"
  local dir="$OUT/$name" sdk_path compiler
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  compiler="$(xcrun --sdk "$sdk" --find clang)"
  mkdir -p "$dir/Headers"
  cat > "$dir/clang-wrapper" <<EOF
#!/bin/sh
exec "$compiler" -target "$target" -isysroot "$sdk_path" "\$@"
EOF
  chmod +x "$dir/clang-wrapper"
  (
    cd "$ROOT/engine"
    GOOS=ios GOARCH="$arch" CGO_ENABLED=1 CC="$dir/clang-wrapper" \
      go build "-mod=$MOD_MODE" -trimpath -buildmode=c-archive \
      -ldflags='-checklinkname=0 -w' -o "$dir/libHiDnetEngine.a" ./cmd/hidnetbridge
  )
  cp "$dir/libHiDnetEngine.h" "$dir/Headers/HiDnetEngine.h"
  cat > "$dir/Headers/module.modulemap" <<'EOF'
module HiDnetEngine {
  header "HiDnetEngine.h"
  export *
}
EOF
}

build_slice ios-arm64 iphoneos arm64 arm64-apple-ios16.0
build_slice sim-arm64 iphonesimulator arm64 arm64-apple-ios16.0-simulator
build_slice sim-x86_64 iphonesimulator amd64 x86_64-apple-ios16.0-simulator
mkdir -p "$OUT/simulator"
lipo -create "$OUT/sim-arm64/libHiDnetEngine.a" "$OUT/sim-x86_64/libHiDnetEngine.a" \
  -output "$OUT/simulator/libHiDnetEngine.a"
rm -rf "$ROOT/Frameworks/HiDnetEngine.xcframework"
xcodebuild -create-xcframework \
  -library "$OUT/ios-arm64/libHiDnetEngine.a" -headers "$OUT/ios-arm64/Headers" \
  -library "$OUT/simulator/libHiDnetEngine.a" -headers "$OUT/sim-arm64/Headers" \
  -output "$ROOT/Frameworks/HiDnetEngine.xcframework"
