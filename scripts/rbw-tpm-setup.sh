#!/usr/bin/env bash
# One-time: seal the Bitwarden master password into the TPM, unlockable by a short PIN.
#
# The PIN is the sealed object's TPM auth value, so guesses are rate-limited by the
# TPM's dictionary-attack lockout — a 6-digit PIN can't be brute-forced offline, and
# the blob is worthless on any other machine. No PCR policy, so kernel/firmware
# updates won't invalidate it.
#
# Re-run this to change the PIN or after a master-password change.
set -euo pipefail

DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rbw-tpm"

command -v tpm2_create >/dev/null || { echo "tpm2-tools not installed"; exit 1; }
[[ -r /dev/tpmrm0 && -w /dev/tpmrm0 ]] || { echo "no access to /dev/tpmrm0 — join the 'tss' group and re-login"; exit 1; }

read -rsp "Bitwarden master password: " MPW; echo
[[ -n "$MPW" ]] || { echo "empty master password"; exit 1; }
read -rsp "New PIN: " PIN; echo
read -rsp "Confirm PIN: " PIN2; echo
[[ "$PIN" == "$PIN2" ]] || { echo "PINs do not match"; exit 1; }
[[ -n "$PIN" ]] || { echo "empty PIN"; exit 1; }

mkdir -p "$DIR"; chmod 700 "$DIR"
rm -f "$DIR"/primary.ctx "$DIR"/seal.pub "$DIR"/seal.priv

# The primary is never persisted — a saved primary context fails its integrity
# check after a TPM reset/reboot. Only seal.pub/seal.priv are kept; the wrapper
# recreates the deterministic primary on demand to unwrap them.
pctx=$(mktemp); ctx=$(mktemp); trap 'rm -f "$pctx" "$ctx"' EXIT
tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null
printf '%s' "$MPW" | tpm2_create -C "$pctx" \
    -u "$DIR/seal.pub" -r "$DIR/seal.priv" -i - -p "$PIN" >/dev/null
chmod 600 "$DIR"/seal.pub "$DIR"/seal.priv

# verify round-trip via a freshly recreated primary — the exact runtime path
tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null
tpm2_load -C "$pctx" -u "$DIR/seal.pub" -r "$DIR/seal.priv" -c "$ctx" >/dev/null
got=$(tpm2_unseal -c "$ctx" -p "$PIN" 2>/dev/null) || { echo "FAILED: unseal did not work"; exit 1; }
[[ "$got" == "$MPW" ]] || { echo "FAILED: unsealed value does not match"; exit 1; }

echo "Sealed to TPM. Point rbw at the PIN wrapper:"
echo "  rbw config set pinentry \$HOME/.dotfiles/scripts/rbw-pinentry.sh"
