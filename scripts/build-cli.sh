#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SWIFTC_BIN="${SWIFTC_BIN:-$(xcrun --find swiftc)}"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"

mkdir -p "$OUTPUT_DIR"

echo "Building buoy CLI..."
"${SWIFTC_BIN}" \
  -sdk "$SDK_PATH" \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/buoy/main.swift \
  -o "$OUTPUT_DIR/buoy"

chmod +x "$OUTPUT_DIR/buoy"
echo "CLI built at $OUTPUT_DIR/buoy"
