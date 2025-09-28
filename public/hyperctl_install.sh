#!/usr/bin/env sh
set -euo pipefail

OWNER=${OWNER:-openlabs-hq}
REPO=${REPO:-hyperctl}
ASSET_NAME=${ASSET_NAME:-hyperctl-linux-amd64}
BINARY_NAME=${BINARY_NAME:-hyperctl}
INSTALL_DIR=${INSTALL_DIR:-/usr/local/bin}
DOWNLOAD_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${ASSET_NAME}"

err() {
  printf "hyperctl installer error: %s\n" "$1" >&2
}

die() {
  err "$1"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_cmd curl
require_cmd install

OS=$(uname -s || true)
ARCH=$(uname -m || true)

[ "$OS" = "Linux" ] || die "Unsupported OS '$OS'; hyperctl currently targets Linux."
[ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ] || die "Unsupported architecture '$ARCH'; hyperctl currently targets x86_64."

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

TMP_BIN="$TMP_DIR/$BINARY_NAME"
printf "Downloading %s to %s...\n" "$ASSET_NAME" "$TMP_BIN"

curl -fsSL "$DOWNLOAD_URL" -o "$TMP_BIN" || die "Failed to download asset from $DOWNLOAD_URL"
chmod 0755 "$TMP_BIN"

TARGET="$INSTALL_DIR/$BINARY_NAME"

install_binary() {
  install -m 0755 "$TMP_BIN" "$TARGET"
}

if [ -w "$INSTALL_DIR" ]; then
  install_binary
else
  if command -v sudo >/dev/null 2>&1; then
    printf "Elevating privileges to write into %s...\n" "$INSTALL_DIR"
    sudo install -m 0755 "$TMP_BIN" "$TARGET"
  else
    die "Cannot write to $INSTALL_DIR. Re-run with sudo or set INSTALL_DIR to a writable path."
  fi
fi

printf "hyperctl installed to %s\n" "$TARGET"

if command -v "$BINARY_NAME" >/dev/null 2>&1; then
  printf "Detected %s version: %s\n" "$BINARY_NAME" "$($BINARY_NAME --version 2>/dev/null || echo 'unknown')"
else
  err "Binary not found on PATH; ensure %s is in your PATH." "$INSTALL_DIR"
fi
