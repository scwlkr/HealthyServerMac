#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SWIFTC="${SWIFTC:-xcrun swiftc}"

mkdir -p "$OUTPUT_DIR"

echo "Building buoy CLI..."
"${SWIFTC}" \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/buoy/main.swift \
  -o "$OUTPUT_DIR/buoy"

chmod +x "$OUTPUT_DIR/buoy"
echo "CLI built at $OUTPUT_DIR/buoy"
