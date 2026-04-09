#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/dist/release}"

mkdir -p "$RELEASE_DIR"

OUTPUT_DIR="$RELEASE_DIR" "$ROOT_DIR/scripts/build-cli.sh"
OUTPUT_DIR="$RELEASE_DIR" "$ROOT_DIR/scripts/build-app.sh"

rm -f "$RELEASE_DIR/Buoy.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$RELEASE_DIR/Buoy.app" "$RELEASE_DIR/Buoy.app.zip"

echo "Release assets prepared in $RELEASE_DIR"
