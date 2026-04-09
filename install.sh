#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
DOWNLOAD_REPO="${DOWNLOAD_REPO:-scwlkr/HealthyServerMac}"
DOWNLOAD_REF="${DOWNLOAD_REF:-main}"
DOWNLOAD_RELEASES="${DOWNLOAD_RELEASES:-1}"

usage() {
  cat <<EOF
Usage:
  ./install.sh [--bin-dir DIR] [--app-dir DIR]

Environment:
  BIN_DIR       Override the CLI install directory.
  APP_DIR       Override the app install directory.
  DOWNLOAD_REPO Override the GitHub repo used for remote installs.
  DOWNLOAD_REF  Override the Git ref used for remote installs.
  DOWNLOAD_RELEASES  Set to 0 to skip release asset downloads.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      shift
      BIN_DIR="$1"
      ;;
    --app-dir)
      shift
      APP_DIR="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

mkdir -p "$BIN_DIR" "$APP_DIR"

download_release_assets() {
  local tmp_dir="$1"
  local base_url="https://github.com/$DOWNLOAD_REPO/releases/latest/download"
  curl -fsSL "$base_url/buoy" -o "$tmp_dir/buoy" || return 1
  curl -fsSL "$base_url/Buoy.app.zip" -o "$tmp_dir/Buoy.app.zip" || return 1
  return 0
}

if [[ -f "$ROOT_DIR/Sources/BuoyCore/BuoyEngine.swift" ]]; then
  SOURCE_DIR="$ROOT_DIR"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  if [[ "$DOWNLOAD_RELEASES" == "1" ]] && download_release_assets "$TMP_DIR"; then
    echo "Using latest release assets from $DOWNLOAD_REPO"
    cp "$TMP_DIR/buoy" "$BIN_DIR/buoy"
    chmod +x "$BIN_DIR/buoy"
    ln -sf "$BIN_DIR/buoy" "$BIN_DIR/healthyservermac"
    rm -rf "$APP_DIR/Buoy.app"
    ditto -x -k "$TMP_DIR/Buoy.app.zip" "$APP_DIR"
    echo "Installed buoy at $BIN_DIR/buoy"
    echo "Installed healthyservermac alias at $BIN_DIR/healthyservermac"
    echo "Installed Buoy.app at $APP_DIR/Buoy.app"
    exit 0
  fi

  ARCHIVE_URL="https://codeload.github.com/$DOWNLOAD_REPO/tar.gz/refs/heads/$DOWNLOAD_REF"
  echo "Falling back to source build from $ARCHIVE_URL"
  curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP_DIR"
  SOURCE_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'HealthyServerMac-*' | head -n 1)"
fi

OUTPUT_DIR="$SOURCE_DIR/dist"
OUTPUT_DIR="$OUTPUT_DIR" "$SOURCE_DIR/scripts/build-cli.sh"
OUTPUT_DIR="$OUTPUT_DIR" "$SOURCE_DIR/scripts/build-app.sh"

cp "$OUTPUT_DIR/buoy" "$BIN_DIR/buoy"
chmod +x "$BIN_DIR/buoy"
ln -sf "$BIN_DIR/buoy" "$BIN_DIR/healthyservermac"

rm -rf "$APP_DIR/Buoy.app"
cp -R "$OUTPUT_DIR/Buoy.app" "$APP_DIR/Buoy.app"

echo "Installed buoy at $BIN_DIR/buoy"
echo "Installed healthyservermac alias at $BIN_DIR/healthyservermac"
echo "Installed Buoy.app at $APP_DIR/Buoy.app"
