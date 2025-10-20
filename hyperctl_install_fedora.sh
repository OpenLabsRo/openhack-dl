#!/usr/bin/env sh

OWNER=openlabsro
REPO=openhack-hypervisor
ASSET_NAME=hyperctl
BINARY_NAME=hyperctl
INSTALL_DIR=/usr/local/bin
DOWNLOAD_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${ASSET_NAME}"

err() {
  printf "hyperctl installer error: %s\n" "$1" >&2
}

die() {
  err "$1"
  exit 1
}

usage() {
  cat <<USAGE
Usage: ./hyperctl_install_fedora.sh [--nodeps|-nodeps]

Installs the hyperctl binary (and, by default, its Fedora-based prerequisites:
Go 1.25.1, redis, vim, git, and the swag CLI).

Options:
  --nodeps, -nodeps  Skip installing prerequisite packages and toolchains.
  -h, --help         Show this help text.
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "This action requires root privileges. Re-run as root or install dependencies manually with --nodeps."
  fi
}

append_path_entry() {
  ENTRY=$1

  case ":${PATH}:" in
    *":${ENTRY}:"*) ;;
    *) PATH="${PATH}:${ENTRY}"
       export PATH
       ;;
  esac

  PROFILE_PATH="${HOME}/.profile"

  if [ ! -e "$PROFILE_PATH" ]; then
    if ! touch "$PROFILE_PATH" 2>/dev/null; then
      printf "Warning: unable to create %s to persist PATH entry %s\n" "$PROFILE_PATH" "$ENTRY"
      return
    fi
  fi

  if [ -w "$PROFILE_PATH" ]; then
    if ! grep -qs "$ENTRY" "$PROFILE_PATH"; then
      printf 'export PATH="$PATH:%s"\n' "$ENTRY" >>"$PROFILE_PATH"
      printf "Added %s to PATH in %s\n" "$ENTRY" "$PROFILE_PATH"
    fi
  else
    printf "Warning: %s is not writable; ensure %s is on PATH manually.\n" "$PROFILE_PATH" "$ENTRY"
  fi
}

install_go_toolchain() {
  REQUIRED_GO_VERSION="go1.25.1"
  GO_ARCHIVE="${REQUIRED_GO_VERSION}.linux-amd64.tar.gz"
  GO_URL="https://go.dev/dl/${GO_ARCHIVE}"

  CURRENT_GO_VERSION=""
  if command -v go >/dev/null 2>&1; then
    CURRENT_GO_VERSION="$(go version | awk '{print $3}')"
  fi

  if [ "$CURRENT_GO_VERSION" = "$REQUIRED_GO_VERSION" ]; then
    printf "Go %s already installed; skipping download.\n" "$CURRENT_GO_VERSION"
    return
  fi

  printf "Installing Go %s...\n" "$REQUIRED_GO_VERSION"

  GO_TMP_DIR=$(mktemp -d)
  GO_TARBALL="${GO_TMP_DIR}/${GO_ARCHIVE}"

  if ! curl -fsSL "$GO_URL" -o "$GO_TARBALL"; then
    rm -rf "$GO_TMP_DIR"
    die "Failed to download Go toolchain from ${GO_URL}"
  fi

  run_privileged rm -rf /usr/local/go
  run_privileged tar -C /usr/local -xzf "$GO_TARBALL"

  rm -rf "$GO_TMP_DIR"

  printf "Go %s installed to /usr/local/go.\n" "$REQUIRED_GO_VERSION"
}

install_swag_cli() {
  if command -v swag >/dev/null 2>&1; then
    printf "swag CLI already present (%s).\n" "$(swag --version 2>/dev/null | head -n 1 || echo "version unknown")"
    return
  fi

  command -v go >/dev/null 2>&1 || die "Go command not available; cannot install swag CLI."

  printf "Installing swag CLI via go install...\n"
  go install github.com/swaggo/swag/cmd/swag@latest

  GOPATH_BIN="$(go env GOPATH 2>/dev/null)/bin"
  if [ -n "$GOPATH_BIN" ] && [ -d "$GOPATH_BIN" ]; then
    append_path_entry "$GOPATH_BIN"
  fi

  if command -v swag >/dev/null 2>&1; then
    printf "swag CLI installed successfully.\n"
  else
    printf "Warning: swag CLI installed but not found on PATH. Ensure %s is on PATH.\n" "$GOPATH_BIN"
  fi
}

install_dependencies() {
  printf "Installing hyperctl prerequisites for Fedora-based systems...\n"

  if ! command -v dnf >/dev/null 2>&1; then
    die "dnf is required to install dependencies automatically. Use --nodeps to skip."
  fi

  run_privileged dnf install -y curl git redis vim

  install_go_toolchain
  append_path_entry "/usr/local/go/bin"

  if command -v go >/dev/null 2>&1; then
    printf "Go ready: %s\n" "$(go version)"
  else
    die "Go installation failed or go not on PATH."
  fi

  install_swag_cli
}

INSTALL_DEPS=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --nodeps|-nodeps)
      INSTALL_DEPS=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [ "$INSTALL_DEPS" -eq 1 ]; then
  install_dependencies
else
  printf "Skipping dependency installation (--nodeps).\n"
fi

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
printf "Downloading %s to temporary folder %s...\n" "$ASSET_NAME" "$TMP_BIN"

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
  printf "Detected %s version: %s\n" "$BINARY_NAME" "$($BINARY_NAME version 2>/dev/null || echo 'unknown')"
else
  err "Binary not found on PATH; ensure ${INSTALL_DIR} is in your PATH."
fi
