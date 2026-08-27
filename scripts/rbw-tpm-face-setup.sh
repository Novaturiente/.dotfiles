#!/usr/bin/env bash
# One-time: seal the Bitwarden master password into the TPM under a ROOT-ONLY auth
# value, so face unlock can release it via pkexec without you typing a PIN.
#
# This is deliberately a second, independent blob. The user-side PIN blob created by
# rbw-tpm-setup.sh stays exactly as it is and remains the fallback, so a broken camera,
# a missing polkit agent, or a plain terminal `rbw` call all still work as before.
#
# Run with sudo. Re-run after a master-password change.
set -euo pipefail

DIR=/etc/rbw-tpm

[[ $EUID -eq 0 ]] || { echo "run this with sudo"; exit 1; }
command -v tpm2_create >/dev/null || { echo "tpm2-tools not installed"; exit 1; }
[[ -w /dev/tpmrm0 ]] || { echo "no access to /dev/tpmrm0"; exit 1; }

read -rsp "Bitwarden master password: " MPW; echo
[[ -n "$MPW" ]] || { echo "empty master password"; exit 1; }

install -d -m 700 -o root -g root "$DIR"

# The auth value is random and never shown: nothing needs to memorise it, and it is
# only ever read by the root helper. This is what a PIN would have been, except it
# can be full entropy because no human types it.
#
# 16 bytes -> 32 hex characters. A TPM auth value cannot exceed the name algorithm's
# digest size, so with sha256 anything over 32 bytes fails with the thoroughly
# unhelpful "ERROR: get password / Invalid key authorization". No trailing newline,
# because file: hands the raw file contents to the TPM.
umask 077
openssl rand -hex 16 | tr -d '\n' > "$DIR/auth.new"
chmod 600 "$DIR/auth.new"

pctx=$(mktemp); ctx=$(mktemp)
trap 'rm -f "$pctx" "$ctx" "$DIR/auth.new"' EXIT

tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null
printf '%s' "$MPW" | tpm2_create -C "$pctx" \
    -u "$DIR/seal.pub.new" -r "$DIR/seal.priv.new" -i - \
    -p "file:$DIR/auth.new" >/dev/null

# Verify the exact runtime path — fresh primary, load, unseal — before replacing
# anything. A half-written seal that fails at unlock time is worse than no seal.
tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null
tpm2_load -C "$pctx" -u "$DIR/seal.pub.new" -r "$DIR/seal.priv.new" -c "$ctx" >/dev/null
got=$(tpm2_unseal -c "$ctx" -p "file:$DIR/auth.new" 2>/dev/null) || {
    echo "FAILED: unseal did not work"; rm -f "$DIR"/*.new; exit 1; }
[[ "$got" == "$MPW" ]] || {
    echo "FAILED: unsealed value does not match"; rm -f "$DIR"/*.new; exit 1; }

mv "$DIR/seal.pub.new"  "$DIR/seal.pub"
mv "$DIR/seal.priv.new" "$DIR/seal.priv"
mv "$DIR/auth.new"      "$DIR/auth"
chmod 600 "$DIR"/seal.pub "$DIR"/seal.priv "$DIR"/auth
trap - EXIT; rm -f "$pctx" "$ctx"

echo "Sealed to TPM under a root-only auth value."
echo "Face unlock is now available to Mod+Shift+P via pkexec."
