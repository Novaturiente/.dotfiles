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

**The pre-scan IR script must go through systemd.** `polkit-agent-helper` runs
with `ProtectHome=yes`, so a direct `linux-enable-ir-emitter` call cannot read
its config in `/root` and the scan sees a dark frame. Covered in
HOWDY-FACE-AUTH.md.

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
