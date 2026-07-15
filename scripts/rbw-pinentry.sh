#!/usr/bin/env bash
# pinentry shim for rbw: asks for a short PIN, unseals the master password from the
# TPM, and hands that to rbw over the Assuan protocol. Set up by rbw-tpm-setup.sh:
#   rbw config set pinentry $HOME/.dotfiles/scripts/rbw-pinentry.sh
#
# If the TPM blob is missing or the PIN is wrong, we fall back to prompting for the
# master password directly — a broken TPM must never lock you out of the vault.
set -uo pipefail

DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rbw-tpm"
REAL_PINENTRY="${RBW_REAL_PINENTRY:-pinentry-qt}"

# Ask the GUI pinentry for a secret; prints it raw. $1 = prompt, $2 = description.
ask() {
    printf 'SETTITLE Bitwarden\nSETPROMPT %s\nSETDESC %s\nGETPIN\nBYE\n' "$1" "$2" |
        "$REAL_PINENTRY" 2>/dev/null | sed -n 's/^D //p' | head -1
}

unseal() {   # $1 = pin
    local pctx ctx out rc
    pctx=$(mktemp) || return 1
    ctx=$(mktemp) || { rm -f "$pctx"; return 1; }
    # Recreate the primary from the same template instead of loading a saved context:
    # a stored primary context fails its integrity check after a TPM reset/reboot,
    # which the caller would misread as a wrong PIN. The owner-hierarchy primary is
    # deterministic, so this reproduces the exact key that wraps the sealed blob.
    tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null 2>&1 &&
    tpm2_load -C "$pctx" -u "$DIR/seal.pub" -r "$DIR/seal.priv" -c "$ctx" >/dev/null 2>&1 || {
        rm -f "$pctx" "$ctx"; return 1; }
    out=$(tpm2_unseal -c "$ctx" -p "$1" 2>/dev/null); rc=$?
    rm -f "$pctx" "$ctx"
    [[ $rc -eq 0 && -n "$out" ]] || return 1
    printf '%s' "$out"
}

master_password() {
    if [[ -r "$DIR/seal.priv" ]] && command -v tpm2_unseal >/dev/null && [[ -w /dev/tpmrm0 ]]; then
        local pin mpw
        pin=$(ask "PIN:" "Unlock Bitwarden vault")
        [[ -n "$pin" ]] || return 1                      # user cancelled
        if mpw=$(unseal "$pin"); then printf '%s' "$mpw"; return 0; fi
        # wrong PIN (or TPM lockout) — let them in with the master password instead
        ask "Master password:" "Wrong PIN — enter the Bitwarden MASTER PASSWORD (not the PIN)"
        return 0
    fi
    # No TPM: usually means this process tree has no 'tss' group membership (agent
    # started before the usermod — fix with `rbw stop-agent`, then unlock from a shell
    # that has the group). Say so, or the prompt looks like a PIN prompt that rejects you.
    ask "Master password:" "TPM unavailable — enter the Bitwarden MASTER PASSWORD (not the PIN)"
}

# Assuan: escape %, CR and LF in the data line.
escape() { printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' -e 's/$/%0A/' | tr -d '\n' | sed 's/%0A$//'; }

printf 'OK Pleased to meet you\n'
while IFS= read -r line; do
    case "${line%% *}" in
    GETPIN)
        if secret=$(master_password) && [[ -n "$secret" ]]; then
            printf 'D %s\nOK\n' "$(escape "$secret")"
        else
            printf 'ERR 83886179 Operation cancelled\n'   # gpg's "cancelled" code
        fi
        ;;
    BYE) printf 'OK closing connection\n'; exit 0 ;;
    *)   printf 'OK\n' ;;
    esac
done
