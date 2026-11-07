#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
STAGING="$(mktemp -d "$ROOT/build/source-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
SOURCE="$STAGING/HiDnet-source"
mkdir -p "$SOURCE"
git -C "$ROOT" archive HEAD | tar -xf - -C "$SOURCE"
(
  cd "$ROOT/engine"
  go mod verify
  go mod vendor -o "$SOURCE/engine/vendor"
  git diff --exit-code -- go.mod go.sum
)
GO_ROOT="$(go env GOROOT)"
mkdir -p "$SOURCE/toolchain-source/go"
cp -R "$GO_ROOT/src" "$SOURCE/toolchain-source/go/src"
cp "$GO_ROOT/LICENSE" "$SOURCE/toolchain-source/go/LICENSE"
if [[ -f "$GO_ROOT/PATENTS" ]]; then
  cp "$GO_ROOT/PATENTS" "$SOURCE/toolchain-source/go/PATENTS"
fi
git -C "$ROOT" rev-parse HEAD > "$SOURCE/SOURCE_COMMIT"
go version > "$SOURCE/GO_VERSION"
cat > "$SOURCE/SOURCE_BUILD.md" <<'EOF'
# Corresponding source

This archive contains the HiDnet revision in SOURCE_COMMIT, the Go dependencies
used by the engine including their license files in engine/vendor, and the Go
standard library/toolchain source in toolchain-source/go. Apple's system SDKs
are supplied separately by Xcode and are not included.

Rebuild on macOS with Xcode, Go 1.26.6 and XcodeGen 2.42+:

    HIDNET_GO_MOD_MODE=vendor bash scripts/build-core.sh
    xcodegen generate
    xcodebuild -project HiDnet.xcodeproj -scheme HiDnet \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath build/HiDnet.xcarchive CODE_SIGNING_ALLOWED=NO archive
    python3 scripts/package-ipa.py --ad-hoc-sign

See README.md and docs/BUILDING.md for signing and installation requirements.
EOF
tar -czf "$ROOT/build/HiDnet-source.tar.gz" -C "$STAGING" HiDnet-source
(
  cd "$ROOT/build"
  shasum -a 256 HiDnet-source.tar.gz > HiDnet-source.tar.gz.sha256
)
