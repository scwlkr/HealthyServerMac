#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Smoke check: source tree"
test -f "$ROOT_DIR/Sources/BuoyCore/BuoyEngine.swift"
test -f "$ROOT_DIR/Sources/buoy/main.swift"
test -f "$ROOT_DIR/Sources/BuoyApp/main.swift"

echo "Smoke check: build scripts"
test -x "$ROOT_DIR/scripts/build-cli.sh" || test -f "$ROOT_DIR/scripts/build-cli.sh"
test -x "$ROOT_DIR/scripts/build-app.sh" || test -f "$ROOT_DIR/scripts/build-app.sh"

echo "Smoke check: installer"
test -f "$ROOT_DIR/install.sh"

echo "Smoke checks passed."
