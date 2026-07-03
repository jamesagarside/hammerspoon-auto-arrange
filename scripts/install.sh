#!/usr/bin/env bash
#
# SnapBack one-line installer
#
#   curl -fsSL https://raw.githubusercontent.com/jamesagarside/snapback/main/scripts/install.sh | bash
#
# Installs Hammerspoon (via Homebrew) if missing, installs SnapBack.spoon,
# and wires it into ~/.hammerspoon/init.lua. Safe to re-run: upgrades the
# Spoon in place and never duplicates init.lua entries.

set -euo pipefail

REPO="jamesagarside/snapback"
SPOON_NAME="SnapBack"
HS_DIR="$HOME/.hammerspoon"
SPOONS_DIR="$HS_DIR/Spoons"
INIT_FILE="$HS_DIR/init.lua"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "SnapBack only runs on macOS."

# 1. Hammerspoon
if [ -d "/Applications/Hammerspoon.app" ] || [ -d "$HOME/Applications/Hammerspoon.app" ]; then
    ok "Hammerspoon is already installed"
elif command -v brew >/dev/null 2>&1; then
    info "Installing Hammerspoon via Homebrew..."
    brew install --cask hammerspoon
else
    fail "Hammerspoon is not installed and Homebrew was not found.
Install Hammerspoon from https://www.hammerspoon.org/ (or install Homebrew from https://brew.sh/), then re-run this script."
fi

# 2. Download the Spoon: latest release asset, falling back to main branch source
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

info "Downloading ${SPOON_NAME}.spoon..."
if curl -fsSL -o "$TMP_DIR/spoon.zip" \
        "https://github.com/$REPO/releases/latest/download/${SPOON_NAME}.spoon.zip" 2>/dev/null; then
    unzip -qo "$TMP_DIR/spoon.zip" -d "$TMP_DIR"
else
    info "No release asset found; using the latest source from main"
    curl -fsSL -o "$TMP_DIR/src.tar.gz" "https://github.com/$REPO/archive/refs/heads/main.tar.gz"
    tar -xzf "$TMP_DIR/src.tar.gz" -C "$TMP_DIR"
    mv "$TMP_DIR/snapback-main/${SPOON_NAME}.spoon" "$TMP_DIR/${SPOON_NAME}.spoon"
fi
[ -d "$TMP_DIR/${SPOON_NAME}.spoon" ] || fail "Download failed: ${SPOON_NAME}.spoon not found in archive."

# 3. Install into ~/.hammerspoon/Spoons
mkdir -p "$SPOONS_DIR"
rm -rf "${SPOONS_DIR:?}/${SPOON_NAME}.spoon"
mv "$TMP_DIR/${SPOON_NAME}.spoon" "$SPOONS_DIR/"
ok "Installed to $SPOONS_DIR/${SPOON_NAME}.spoon"

# 4. Wire up init.lua (idempotent)
if [ -f "$INIT_FILE" ] && grep -q "loadSpoon(\"${SPOON_NAME}\")" "$INIT_FILE"; then
    ok "init.lua already loads ${SPOON_NAME}"
else
    info "Adding ${SPOON_NAME} to $INIT_FILE"
    printf '\n-- SnapBack (added by install script)\nhs.loadSpoon("%s")\nspoon.%s:start()\n' \
        "$SPOON_NAME" "$SPOON_NAME" >> "$INIT_FILE"
fi

# 5. Launch or reload
if command -v hs >/dev/null 2>&1 && pgrep -x Hammerspoon >/dev/null 2>&1; then
    info "Reloading Hammerspoon config..."
    hs -c "hs.reload()" >/dev/null 2>&1 || true
else
    info "Starting Hammerspoon..."
    open -a Hammerspoon
fi

ok "Done! Look for the SB icon in your menubar."
echo
echo "First install? macOS will ask you to grant Hammerspoon Accessibility"
echo "permission (System Settings → Privacy & Security → Accessibility) —"
echo "that's required for any window manager to move windows."
