#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APP_DIR="${APP_DIR:-$HOME/Applications}"

rm -f "$BIN_DIR/buoy" "$BIN_DIR/healthyservermac"
rm -rf "$APP_DIR/Buoy.app"

echo "Removed $BIN_DIR/buoy"
echo "Removed $BIN_DIR/healthyservermac"
echo "Removed $APP_DIR/Buoy.app"
