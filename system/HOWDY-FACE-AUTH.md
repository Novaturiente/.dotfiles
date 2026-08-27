# Face Login (Howdy + IR camera)

Windows-Hello-style face authentication on this laptop, using the built-in
**infrared** camera — not the RGB one. Covers `sudo`, the `ly` greeter, the
`dms` lock screen, and polkit prompts.

Three of those four work from one edit to `/etc/pam.d/system-auth`. The `dms`
lock screen needs its own config and its own `pam_howdy` options — that is the
single most surprising part of this setup and has its own section below.

Set up 2026-08-27 on CachyOS. An earlier attempt (Jan 2026) failed and this
document exists mainly to record *why*, because the failure modes are silent
and cost hours to rediscover.

---

## Hardware

| Item | Value |
|---|---|
| Camera | Bison / SunplusIT Integrated RGB Camera |
| USB ID | `5986:2169` |
| USB bus path | `3-5` (i.e. `/sys/bus/usb/devices/3-5`) |
| RGB stream | `/dev/video0` (MJPG + YUYV, up to 1920x1080) |
| **IR stream** | `/dev/video2` (`GREY`, 640x360 @ 30fps) |
| IR stable path | `/dev/v4l/by-path/pci-0000:00:14.0-usb-0:5:1.2-video-index0` |

`/dev/video1` and `/dev/video3` are metadata nodes, not capture devices.

Identify the IR camera on a fresh install with:

```sh
for d in /dev/video*; do echo "== $d"; v4l2-ctl -d "$d" --list-formats-ext; done
```

The IR one is whichever reports `GREY` (8-bit greyscale). **Do not assume it
stays `/dev/video2`** — use the `by-path` name in Howdy's config.

---

## The two quirks that make this hard

Both concern the UVC "extension unit" control that switches the IR emitter on.
`linux-enable-ir-emitter` finds and writes that control; on this camera it is
`unit=7 selector=6`, set to `[1, 3, 2, 0, 0, 0, 0, 0, 0]`.

### 1. USB autosuspend wipes the control

The camera's USB port defaults to `power/control=auto` with a 2000ms
autosuspend delay. When the device suspends it loses the emitter setting, and
every subsequent scan gets a black frame. Fixed by pinning the device powered
via a udev rule scoped to this one USB ID.

Symptom if broken: `All frames were too dark; check dark_threshold`, with
average darkness in the high 80s or 90s.

Cost: the camera stays powered, which uses a little more battery.

### 2. The camera drops the control on its own anyway

Even with autosuspend disabled, the control does not reliably survive between
scans. It has to be re-applied immediately *before* each face scan, not once
at boot. This is done with `pam_exec` in the auth stack.

**A shell wrapper around `/usr/lib/howdy/howdy-auth-helper` does NOT work** —
that binary is setuid, and Linux ignores the setuid bit on scripts. `pam_exec`
is the correct hook; it runs as root inside the auth stack.

### Bonus gotcha: `HOME` must be set

`linux-enable-ir-emitter` expands `$HOME` when building its log file path and
hard-fails if the variable is missing:

```
Error: failed to expend shell variable in log file path
Caused by: error looking key 'HOME' up: environment variable not found
```

Neither systemd units nor PAM provide `HOME`. That is why both the service
and the pre-scan script set `HOME=/root` explicitly. Its config also lives at
`/root/.config/linux-enable-ir-emitter.toml`, so it must run as root.

---

## Install

### 1. Packages

```sh
paru -S --needed linux-enable-ir-emitter-git howdy-next-git
```

Notes on package choice:

- `howdy-next` is the maintained fork. The original `howdy` (2.6.1, Python +
  dlib) breaks against Arch's rolling Python — the Jan 2026 attempt died this
  way and left an unowned `/usr/lib/security/howdy` directory behind.
- The `-git` build of `linux-enable-ir-emitter` ships **only the binary**. No
  systemd unit, no udev rule. Those are provided here instead.

If a previous broken install exists, clear it first:

```sh
sudo rm -rf /usr/lib/security/howdy /etc/howdy
```

### 2. Configure the IR emitter (interactive)

```sh
sudo linux-enable-ir-emitter configure
```

Pick the **`GREY`** device. The tool then walks through UVC controls, flashing
each candidate, and asks *"Is the camera emitter or preview blinking?"* Answer
honestly — say `n` while the preview is a black mess, `y` once it lights up.
The in-terminal preview is a blocky low-res render; it looks far worse than
the actual 640x360 capture, so judge by brightness, not detail.

Result is written to `/root/.config/linux-enable-ir-emitter.toml`, plus a
per-device file under `/etc/linux-enable-ir-emitter/`.

Verify a lit frame:

```sh
sudo linux-enable-ir-emitter run
ffmpeg -f v4l2 -input_format gray -video_size 640x360 -i /dev/video2 \
       -frames:v 30 -f image2 -update 1 /tmp/ir.png
```

A black or ~1KB PNG means the emitter is not firing.

### 3. Drop in the files from this repo

Run from `~/.dotfiles/system` — the paths below are relative to it. The full
contents are reproduced under "File contents" at the end, so this works even
without the repo.

```sh
cd ~/.dotfiles/system

sudo cp system/etc/udev/rules.d/99-ir-camera-power.rules /etc/udev/rules.d/
sudo cp system/etc/systemd/system/linux-enable-ir-emitter.service /etc/systemd/system/
sudo install -m 755 system/usr/local/bin/howdy-ir-pre /usr/local/bin/howdy-ir-pre

sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=usb
sudo systemctl daemon-reload
sudo systemctl enable --now linux-enable-ir-emitter.service
```

Check both landed:

```sh
cat /sys/bus/usb/devices/3-5/power/control   # expect: on
systemctl status linux-enable-ir-emitter     # expect: status=0/SUCCESS
```

A `oneshot` unit shows `inactive (dead)` after succeeding. That is normal.

### 4. Howdy config and enrollment

```sh
sudo howdy download-models

sudo sed -i \
  -e 's|^device_path = .*|device_path = /dev/v4l/by-path/pci-0000:00:14.0-usb-0:5:1.2-video-index0|' \
  -e 's/^dark_threshold = .*/dark_threshold = 95/' \
  -e 's/^timeout = .*/timeout = 6/' \
  /etc/howdy/config.ini

sudo howdy add
```

Config lives at `/etc/howdy/config.ini` (root-only). Only three values differ
from stock:

| Key | Stock | Ours | Why |
|---|---|---|---|
| `device_path` | `none` | IR `by-path` | Point at the IR camera, not RGB |
| `dark_threshold` | `75` | `95` | IR frames are dim; this only gates which frames are *attempted*, not how strict the match is |
| `timeout` | `4` | `6` | More frames to work with on a marginal sensor |
| `detection_notice` | `false` | `true` | Shows "Starting face verification" on the lock screen — useful feedback, keep it |
| `end_report` | `false` | `true` | Timing details in the journal; set back to `false` to quieten logs |

`detection_notice` and `end_report` were enabled while debugging. The first is
worth keeping for user feedback; the second is pure diagnostics:

```sh
sudo sed -i -e 's/^detection_notice = .*/detection_notice = true/' \
            -e 's/^end_report = .*/end_report = true/' /etc/howdy/config.ini
```

`sface_threshold` (the actual face-match strictness) is left at its default of
`0.6942`. Loosening *that* would be the setting that weakens security.

Models are stored in `/etc/howdy/models/`. Manage with `howdy list`,
`howdy add`, `howdy remove`, `howdy clear`.

### 5. PAM

**Open a second terminal with `sudo -i` and leave it there before editing PAM.**
A mistake here can lock you out of authentication entirely.

Three of the four targets funnel into a single file:

- `sudo` → `system-auth`
- `ly` → `login` → `system-local-login` → `system-login` → `system-auth`
- polkit → `/usr/lib/pam.d/polkit-1` → `system-auth`

**The `dms` lock screen does not.** It needs separate handling — see
"DMS lock screen" below. Do not assume `system-auth` covers it; `strings`
on the `dms` binary mentions `system-auth`, which is misleading.

`ly` needs no extra setup beyond this file. It is a TTY greeter, so
`pam_howdy`'s native mode has the real terminal it requires.

Back up, then insert two lines directly after faillock's `preauth` line:

```sh
sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak

sudo sed -i '/pam_faillock.so      preauth/a auth       optional                    pam_exec.so          quiet /usr/local/bin/howdy-ir-pre\nauth       sufficient                  pam_howdy.so         workaround=native-input' /etc/pam.d/system-auth
```

Resulting head of `/etc/pam.d/system-auth`:

```
#%PAM-1.0

auth       required                    pam_faillock.so      preauth
auth       optional                    pam_exec.so          quiet /usr/local/bin/howdy-ir-pre
auth       sufficient                  pam_howdy.so         workaround=native-input
```

Why this exact shape:

- **After `preauth`**, so faillock still counts failed attempts.
- **`pam_exec` is `optional`**, so if the emitter script ever fails the stack
  continues to Howdy and then to the password prompt. It cannot lock you out.
- **`pam_howdy` is `sufficient`**, so a failed or unrecognized face falls
  through to the normal password prompt rather than denying.
- **`workaround=native-input`** rather than `native`. Native mode needs a real
  terminal whose foreground process group matches, which `sudo` and `ly` have
  but a Wayland lock screen does not. Without the `input` fallback, `dms` will
  match your face and then sit there waiting on its password field, because
  nothing submits the empty prompt. The `input` half injects one Enter
  keypress via `/dev/uinput` to close that gap.

`/dev/uinput` needs the `uinput` module loaded and your user in the `input`
group — both are already true on a default CachyOS install. Verify with
`lsmod | grep uinput` and `id | grep input`.

**Revert command**, keep it in the root shell:

```sh
cp /etc/pam.d/system-auth.bak /etc/pam.d/system-auth
```

---

## DMS lock screen

The lock screen is the one target that needs its own configuration, and it
took the longest to get right. Two independent problems.

### Problem 1: dms does not use `/etc/pam.d/system-auth`

The lock screen runs through quickshell, which calls `pam_start_confdir()`
rather than using the standard PAM path. By default dms **generates** a
flattened, self-contained copy of the system auth stack at
`~/.local/state/DankMaterialShell/pam/dankshell` and points PAM at that
directory. It regenerates on each lock, so editing that file by hand is
pointless.

Confirm which config is actually in use — the journal states it outright:

```
quickshell.service.pam.subprocess: Starting pam session for user "nova"
  with config "dankshell" in dir "/home/nova/.local/state/DankMaterialShell/pam"
```

To use a real file instead, set dms's `lockPamPath`. There is a UI control
under Settings ("Which PAM service the lock screen uses to authenticate" →
Custom...), or set it directly:

```sh
jq '.lockPamPath = "/etc/pam.d/dankshell"' \
   ~/.config/DankMaterialShell/settings.json > /tmp/s.json \
  && mv /tmp/s.json ~/.config/DankMaterialShell/settings.json
dms restart
```

After restarting, the journal line must read `in dir "/etc/pam.d"`. If it
still names the state directory, the setting did not take.

Note `dms auth sync` is the official way to write `/etc/pam.d/dankshell`, but
it refuses to run under `sudo` ("This program should not be run as root") and
hangs on an internal privilege prompt when run with `-y`. Writing the file
directly, as below, works fine.

### Problem 2: the `input` workaround prevents the scan

**`workaround=native-input` must NOT be used for the lock screen.** It breaks
face auth there completely, in a way that looks like a camera fault: the IR
emitter never fires and the prompt rejects you instantly.

What happens is that native mode is unavailable (no real terminal in a Wayland
GUI), so howdy falls back to `input`, which installs a uinput observer, waits
for a hidden-input prompt that never arrives in a GUI conversation, and
returns immediately without ever scanning. The journal signature:

```
pam_howdy: Native prompt conversation unavailable, falling back to input workaround
kernel: input: Howdy virtual keyboard as /devices/virtual/input/input109
pam_howdy: pam_unix(dankshell:auth): authentication failure
```

Note the total absence of any verdict line, and that failure lands in the same
second — far too fast for a scan.

The fix is to omit `workaround=` entirely in the lock-screen config. Because
`pam_howdy` is `sufficient`, a successful match short-circuits the stack and
`pam_unix` never prompts, so there is nothing for the workaround to submit.
It is needed under `sudo` and not here.

### Install the lock-screen config

`/etc/pam.d/dankshell` is identical to the generated stack except the
`pam_howdy.so` line carries no `workaround=` option:

```sh
cd ~/.dotfiles/system
sudo install -m 644 -o root -g root \
  system/etc/pam.d/dankshell /etc/pam.d/dankshell
```

**Prefer regenerating it on a fresh install.** The committed copy is a
snapshot of this machine's `system-auth` as flattened by dms; a different
distro release may have a different stack. Regenerate rather than assume:

```sh
# dms writes the flattened stack to the user state dir and prints the path
GEN=$(dms auth resolve-lock --quiet)

# same file, with the workaround option stripped from the pam_howdy line
sed 's/\(pam_howdy\.so\)\s*workaround=\S*/\1/' "$GEN" > /tmp/dankshell.new

sudo install -m 644 -o root -g root /tmp/dankshell.new /etc/pam.d/dankshell
dms auth validate --path /etc/pam.d/dankshell --json   # never under sudo
```

`validate` should report `"valid": true` with empty `missingModules` and
`errors`. Do this **after** step 5, so `system-auth` already contains the
howdy lines that get flattened in.

Working journal output looks like this:

```
quickshell.service.pam.subprocess: Starting pam session for user "nova"
  with config "dankshell" in dir "/etc/pam.d"
pam_howdy: Face verification succeeded
```

If dms's own auth sync ever rewrites this file, re-apply the workaround
removal. The `# BEGIN DMS LOCKSCREEN AUTH` marker comments are retained so
dms recognizes the file as managed rather than custom.

---

## Verify

```sh
sudo -k && sudo true        # expect: "Face matched user nova"
```

Then, at the machine:

- Lock with `dms ipc call lock lock` and look at the camera without pressing
  anything. The scan takes a few seconds and needs no keypress.
- Reboot and wait at the `ly` greeter instead of typing. This doubles as the
  reboot-persistence test for the udev rule and the emitter service.
- Trigger any GUI privilege prompt for polkit.

Useful during any of these — howdy logs every verdict:

```sh
journalctl --since "-3min" | grep -iE "howdy|dankshell|pam_"
```

Recovery if the greeter misbehaves: `Ctrl+Alt+F2` to a TTY, log in with your
password, restore the backup.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `All frames were too dark`, darkness 85+ | Emitter not firing, or you are backlit | Check `power/control` is `on`; run `linux-enable-ir-emitter run` manually and re-test |
| Works once, fails after | The `pam_exec` pre-scan hook is missing or not executable | `sudo /usr/local/bin/howdy-ir-pre` should exit 0 silently |
| `failed to expend shell variable` | `HOME` unset | Confirm `Environment=HOME=/root` in the unit, `HOME=/root` in the script |
| Lock screen: instant reject, IR never fires, no verdict in journal | `workaround=` present in the lock-screen config | Remove the option from `/etc/pam.d/dankshell` |
| Lock screen: edits to `/etc/pam.d/dankshell` have no effect | dms is using its generated state-dir copy | Set `lockPamPath`, then `dms restart`; journal must say `in dir "/etc/pam.d"` |
| `dms auth sync` hangs or refuses to run | Known: rejects root, hangs on internal prompt with `-y` | Write `/etc/pam.d/dankshell` directly |
| Emitter never found by `configure` | Wrong device picked | Re-run and choose the `GREY` device |
| SSH sessions trying to use the camera | — | Already prevented: `abort_if_ssh = true` is Howdy's default |

**Backlighting is the main day-to-day reliability factor.** A lamp or window
behind you is bright in infrared, so auto-exposure stops down for it and
crushes your face to black. Enroll under the lighting you actually log in
with, and add a second model for a different time of day if needed.

---

## Security notes

- IR face auth is a **convenience layer**, defeatable by a photo or an
  IR-visible mask. Password remains the fallback on every surface by design.
- SSH never uses face auth (`abort_if_ssh = true`).
- Face auth is skipped with the lid closed (`abort_if_lid_closed = true`).
- Kill switch without unenrolling: `sudo howdy disable true`, or set
  `disabled = true` in `/etc/howdy/config.ini`.
- `/etc/howdy/config.ini` and `/etc/howdy/models/` must stay root-owned and
  non-user-writable, otherwise a user could enroll their own face for root.

## Not applicable here: TPM / disk unlock

This machine has a TPM (`/dev/tpm0`) but the disk is **not encrypted** —
`nvme0n1p2` is plain btrfs and `/etc/crypttab` is empty. There is nothing for
the TPM to unlock.

Worth noting for the future: face unlock could never unlock a LUKS volume at
boot anyway. That happens in the initramfs, long before PAM, a camera stack,
or Python/OpenCV exist. TPM-backed auto-unlock via `systemd-cryptenroll
--tpm2-device=auto` is an entirely separate mechanism, unrelated to Howdy.

## Maintenance

- `howdy-next-git` is a git package. A rebuild may leave
  `/etc/howdy/config.ini.pacnew`; re-apply the three values from step 4.
- PAM edits live in `/etc/pam.d/system-auth` and are not touched by package
  updates.
- Delete stale `/etc/pam.d/system-auth.bak*` files once the setup is trusted.

---

## File contents

Reproduced so this document is self-sufficient if the repo is unavailable.
These are the same files staged under `system/` in this repo.

### `/etc/udev/rules.d/99-ir-camera-power.rules`

Scoped to this camera's USB ID so no other device is affected.

```
# Bison/SunplusIT IR camera: block USB autosuspend so the UVC emitter control persists
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="5986", ATTR{idProduct}=="2169", TEST=="power/control", ATTR{power/control}="on"
```

### `/etc/systemd/system/linux-enable-ir-emitter.service`

`Environment=HOME=/root` is required — the tool hard-fails without it.
The `WantedBy` list covers resume from every sleep type, not just boot.

```ini
[Unit]
Description=Enable IR emitter on the integrated camera
After=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
Environment=HOME=/root
ExecStart=/usr/bin/linux-enable-ir-emitter run
RemainAfterExit=no

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
```

### `/usr/local/bin/howdy-ir-pre` (mode 755)

```sh
#!/bin/sh
# Re-apply the IR emitter UVC control immediately before a Howdy face scan.
# The camera drops this control on its own; without it every scan sees a dark frame.
HOME=/root exec /usr/bin/linux-enable-ir-emitter run >/dev/null 2>&1
```

### `/etc/pam.d/dankshell` (mode 644, root:root)

Prefer regenerating this rather than copying it verbatim — see the DMS
section. Note `pam_howdy.so` carries **no** `workaround=` option here,
unlike in `system-auth`.

```
#%PAM-1.0
# BEGIN DMS LOCKSCREEN AUTH (managed by dms greeter sync)
auth       requisite    pam_nologin.so
auth       required   pam_shells.so
auth       requisite  pam_nologin.so
auth       required                    pam_faillock.so      preauth
auth       optional                    pam_exec.so          quiet /usr/local/bin/howdy-ir-pre
auth       sufficient                  pam_howdy.so
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=1 default=bad]     pam_unix.so          try_first_pass nullok
auth       [default=die]               pam_faillock.so      authfail
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so      authsucc
account    required   pam_access.so
account    required   pam_nologin.so
-account   [success=1 default=ignore]  pam_systemd_home.so
account    required                    pam_unix.so
account    optional                    pam_permit.so
account    required                    pam_time.so
session    optional   pam_loginuid.so
session    optional   pam_keyinit.so       force revoke
-session   optional                    pam_systemd_home.so
session    required                    pam_limits.so
session    required                    pam_unix.so
session    optional                    pam_permit.so
session    optional   pam_lastlog2.so      silent
session    optional   pam_motd.so
session    optional   pam_mail.so          dir=/var/spool/mail standard quiet
session    optional   pam_umask.so
-session   optional   pam_systemd.so
session    required   pam_env.so
-password  [success=1 default=ignore]  pam_systemd_home.so
password   required                    pam_unix.so          try_first_pass nullok shadow
password   optional                    pam_permit.so
# END DMS LOCKSCREEN AUTH
```
