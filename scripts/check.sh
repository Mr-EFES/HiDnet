#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift test --package-path "$ROOT/Packages/HiDnetCore"
(
  cd "$ROOT/engine"
  go mod verify
  go test -mod=readonly -race -ldflags=-checklinkname=0 ./...
)
