#!/usr/bin/env bash
set -euo pipefail

# PassRofi — One-time setup script

GPG_ID="EA3D3A3B"
PASS_CSV="$HOME/Desktop/pass.csv"

DEPS=(
    "pass-otp"
    "pass-import"
    "browserpass"
    "wtype"
    "zbar"
)

echo "=== PassRofi Setup ==="

# Install missing dependencies
echo "[1/4] Checking dependencies..."
missing=()
for pkg in "${DEPS[@]}"; do
    if ! paru -Qi "$pkg" &>/dev/null; then
        missing+=("$pkg")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Installing: ${missing[*]}"
    paru -S --needed --noconfirm "${missing[@]}"
else
    echo "All dependencies installed."
fi

# Initialize pass store if needed (already exists at ~/.password-store/)
echo "[2/4] Checking pass store..."
if [[ ! -f "$HOME/.password-store/.gpg-id" ]]; then
    echo "Initializing pass store with GPG key $GPG_ID..."
    pass init "$GPG_ID"
else
    echo "Pass store already initialized."
fi

# Import from Firefox CSV if file exists
echo "[3/4] Importing passwords..."
if [[ -f "$PASS_CSV" ]]; then
    echo "Found $PASS_CSV — importing into pass..."
    # pass-import expects: pass import <manager> <file>
    # Firefox CSV format matches what we have
    pass import firefox "$PASS_CSV"
    echo "Import complete. Verify with: pass ls"
    echo ""
    echo "WARNING: Delete $PASS_CSV after verifying import!"
    echo "  rm '$PASS_CSV'"
else
    echo "No CSV found at $PASS_CSV — skipping import."
fi

# Configure browserpass-native
echo "[4/4] Configuring browserpass..."

# Configure browserpass native messaging hosts
# browserpass package includes the native host binary and manifests
BROWSERPASS_HOST="/usr/lib/browserpass/hosts"

# Firefox
FIREFOX_NMH_DIR="$HOME/.mozilla/native-messaging-hosts"
mkdir -p "$FIREFOX_NMH_DIR"
if [[ -f "$BROWSERPASS_HOST/firefox/com.github.browserpass.native.json" ]]; then
    ln -sf "$BROWSERPASS_HOST/firefox/com.github.browserpass.native.json" \
        "$FIREFOX_NMH_DIR/com.github.browserpass.native.json"
    echo "Firefox native messaging host configured."
elif command -v browserpass &>/dev/null; then
    echo "browserpass installed but host manifest not found at expected path — check 'pacman -Ql browserpass' for actual paths."
else
    echo "browserpass not found — skipping native messaging host setup."
fi

# Chrome/Chromium
for browser_dir in \
    "$HOME/.config/google-chrome/NativeMessagingHosts" \
    "$HOME/.config/chromium/NativeMessagingHosts"; do
    mkdir -p "$browser_dir"
    if [[ -f "$BROWSERPASS_HOST/chromium/com.github.browserpass.native.json" ]]; then
        ln -sf "$BROWSERPASS_HOST/chromium/com.github.browserpass.native.json" \
            "$browser_dir/com.github.browserpass.native.json"
    fi
done
echo "Chrome/Chromium native messaging hosts configured."

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Install Browserpass extension in your browser:"
echo "     Firefox: https://addons.mozilla.org/en-US/firefox/addon/browserpass-ce/"
echo "     Chrome:  https://chrome.google.com/webstore/detail/browserpass-ce/naepdomgkenhinolocfifgehidddafch"
echo "  2. Disable your browser's built-in password manager"
echo "  3. Delete $PASS_CSV after verifying import"
echo "  4. Test: press Mod+Shift+P to open PassRofi"
