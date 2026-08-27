# Bitwarden face unlock (rbw + TPM + polkit)

Face unlock for the `Mod+Shift+P` password manager, with the PIN and the master
password still available as fallbacks.

Depends on the face auth setup in [HOWDY-FACE-AUTH.md](HOWDY-FACE-AUTH.md).
Set up 2026-08-27.

---

## The constraint that shapes everything

`rbw` needs the actual master password to derive its vault keys. **A face match
produces no key material** — it is a yes/no verdict. So the master password has
to be stored somewhere and released after a successful face check, and the only
real question is what protects it at rest.

The TPM does. The blob is hardware-bound, worthless on another machine, and
guesses are rate-limited by the TPM's dictionary-attack lockout. **This disk is
not encrypted** (plain btrfs, empty `crypttab`), so a master password sitting in
a file under `$HOME` would be readable by anyone who pulls the drive. Do not
"simplify" this by dropping the TPM.

What the PIN protects against is a process running as your user. So the face
path keeps the TPM and moves the auth value out of your reach instead:

- A **second, independent** sealed blob holds the same master password.
- Its auth value is 32 random hex characters at `/etc/rbw-tpm/auth`, `0600`
  root. No human ever types or sees it.
- A root helper unseals it, reached only through `pkexec`, so polkit performs a
  real authentication first — face via `pam_howdy`, login password as fallback.
- A process running as you still cannot get the master password without passing
  that check.

The original PIN blob in `~/.local/share/rbw-tpm` is untouched and remains the
fallback, so `rbw` from a terminal works exactly as before.

---

## Pieces

| Path | What |
|---|---|
| `/etc/rbw-tpm/{auth,seal.pub,seal.priv}` | Root-only auth value and sealed blob |
| `/usr/local/libexec/rbw-tpm-face-unseal` | Root helper; unseals and prints to stdout |
| `/usr/share/polkit-1/actions/dev.novaturiente.rbw-tpm.policy` | `auth_self` action gating that helper |
| `scripts/rbw-tpm-face-setup.sh` | One-time seal (run with sudo) |
| `scripts/rbw-pinentry.sh` | pinentry shim: face → PIN → master password |
| `scripts/quickshell/pass.sh` | Drops the face-request flag before unlocking |

Install:

```sh
cd ~/.dotfiles
sudo install -D -m 755 system/system/usr/local/libexec/rbw-tpm-face-unseal \
                       /usr/local/libexec/rbw-tpm-face-unseal
sudo install -D -m 644 system/system/usr/share/polkit-1/actions/dev.novaturiente.rbw-tpm.policy \
                       /usr/share/polkit-1/actions/dev.novaturiente.rbw-tpm.policy
pkaction --action-id dev.novaturiente.rbw-tpm.unseal --verbose   # confirm polkit parsed it
sudo ./scripts/rbw-tpm-face-setup.sh                             # prompts master password once
```

Verify:

```sh
rbw lock
touch "$XDG_RUNTIME_DIR/rbw-face-request"
rbw unlock && echo "VAULT UNLOCKED"
```

The journal should show `Face verification succeeded` followed by
`pkexec ... Executing command`.

---

## Gotchas

**The polkit prompt wants your LOGIN password, not the Bitwarden master
password.** polkit authenticates your user account — that is the entire
mechanism protecting the blob. Typing the Bitwarden password there fails, and
three failures faillock the account for 10 minutes. See the faillock section in
HOWDY-FACE-AUTH.md.

**A TPM auth value cannot exceed the name algorithm's digest size** — 32 bytes
with sha256. `openssl rand -hex 32` gives 64 characters and fails with the
thoroughly misleading `ERROR: get password / ERROR: Invalid key authorization`,
which reads like a permissions or format problem. Use `-hex 16`.

**A flag file, not an environment variable.** `rbw-agent` — not `pass.sh` —
spawns the pinentry shim, so the shim's environment comes from the daemon and
would never carry the request. `pass.sh` touches
`$XDG_RUNTIME_DIR/rbw-face-request` and the shim consumes it. That the flag is
user-writable grants nothing: it only routes to `pkexec`, which still
authenticates.

**polkit needs a running authentication agent.** Without one, `pkexec` from a
non-terminal process fails outright. See HOWDY-FACE-AUTH.md.

**A polkit dialog on every sudo means `howdy-ir-pre` has its routes the wrong
way round.** `pam_exec` runs its command with the REAL user ID unless given
`seteuid`, so under `sudo` the script runs as your user, and `systemctl start`
on a system unit then needs polkit authorization. The script must try the
direct call first and fall back to `systemctl` only when it cannot read the
emitter config — which is the signal that it is inside polkit's `ProtectHome`
sandbox, where the caller is root and `systemctl` does not prompt. Full
reasoning in HOWDY-FACE-AUTH.md.

Treat a stray polkit prompt as urgent rather than cosmetic: three cancelled or
failed dialogs faillock the account for 10 minutes.

---

## After a master-password change

Re-seal **both** blobs, or the stale one hands `rbw` the old password:

```sh
./scripts/rbw-tpm-setup.sh          # PIN blob, in $HOME
sudo ./scripts/rbw-tpm-face-setup.sh   # face blob, in /etc
```

Both prompt without echoing. If characters appear as you type, stop — that is
the shell prompt, not the script, and your master password is about to land in
shell history.

---

## Scope

Face unlock is deliberately wired only to `Mod+Shift+P`, because `pass.sh` is
what sets the flag. Any other caller — `rbw` in a terminal, or the agent lock
expiring during other use — gets the normal PIN prompt. To make it apply
everywhere, set the flag from a wrapper around `rbw` instead, or have the shim
attempt the face path unconditionally and fall through on failure.

---

## File contents

Reproduced so this document is self-sufficient without the repo.

### `/usr/local/libexec/rbw-tpm-face-unseal` (mode 755, root:root)

```sh
#!/bin/sh
# Release the Bitwarden master password from the TPM using a root-only auth value.
#
# Invoked through pkexec; polkit does the actual authentication, which on this
# machine means face (pam_howdy) with the login password as fallback. The auth
# value lives at /etc/rbw-tpm/auth (root, 0600) precisely so a process running
# as the user cannot unseal without passing that polkit check.
#
# Takes no arguments and reads only fixed paths — nothing here is caller-controlled.
set -eu

DIR=/etc/rbw-tpm

[ -r "$DIR/auth" ] && [ -r "$DIR/seal.priv" ] || {
    echo "rbw-tpm: not configured — run scripts/rbw-tpm-face-setup.sh" >&2
    exit 1
}

pctx=$(mktemp) || exit 1
ctx=$(mktemp) || { rm -f "$pctx"; exit 1; }
trap 'rm -f "$pctx" "$ctx"' EXIT

# Recreate the deterministic owner-hierarchy primary rather than loading a saved
# context: a stored primary fails its integrity check after a TPM reset or reboot.
# Same reasoning as the user-side PIN wrapper.
tpm2_createprimary -C o -g sha256 -G ecc -c "$pctx" >/dev/null 2>&1 || {
    echo "rbw-tpm: createprimary failed" >&2; exit 1; }
tpm2_load -C "$pctx" -u "$DIR/seal.pub" -r "$DIR/seal.priv" -c "$ctx" >/dev/null 2>&1 || {
    echo "rbw-tpm: load failed" >&2; exit 1; }

# Raw bytes, no trailing newline — the caller feeds this straight to rbw.
tpm2_unseal -c "$ctx" -p "file:$DIR/auth"
```

### `/usr/share/polkit-1/actions/dev.novaturiente.rbw-tpm.policy` (mode 644)

`auth_self` rather than `auth_self_keep`: every unlock re-authenticates, since
caching the grant would defeat the point of requiring a live face match.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <vendor>Novaturiente dotfiles</vendor>
  <vendor_url>https://github.com/Novaturiente/.dotfiles</vendor_url>

  <!-- auth_self, not auth_self_keep: every unlock re-authenticates. The whole
       point is that releasing the master password requires a live face match
       (or the login password), so caching the grant would defeat it. -->
  <action id="dev.novaturiente.rbw-tpm.unseal">
    <description>Unlock Bitwarden vault</description>
    <message>Authenticate to unlock your Bitwarden vault</message>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>auth_self</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/libexec/rbw-tpm-face-unseal</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
```

### Changes to existing scripts

`scripts/quickshell/pass.sh` drops the request flag before unlocking, ahead of
opening the UI so the polkit dialog is not rendered underneath it:

```sh
: > "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rbw-face-request" 2>/dev/null || true
```

`scripts/rbw-pinentry.sh` gains a `try_face` step ahead of the PIN path. It
consumes the flag before attempting, so a failure falls through to the PIN
instead of looping:

```sh
try_face() {
    [[ -e "$FACE_FLAG" ]] || return 1
    rm -f "$FACE_FLAG"
    [[ -x "$FACE_UNSEAL" ]] && command -v pkexec >/dev/null || return 1
    pkexec "$FACE_UNSEAL" 2>/dev/null
}
```
