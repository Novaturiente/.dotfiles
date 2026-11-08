# Face Login (Howdy + IR camera)

Windows-Hello-style face authentication on this laptop, using the built-in
**infrared** camera — not the RGB one. Covers `sudo`, the `ly` greeter, the
`swaylock` lock screen, and polkit prompts.

Three of those four work from one edit to `/etc/pam.d/system-auth`. The
lock screen needs its own PAM file and its own `pam_howdy` options — that is
the single most surprising part of this setup and has its own section below.

Under both Hyprland and niri, swayidle and Mod+Shift+L run `scripts/lock.sh`,
which execs `swaylock`. Its PAM file is tracked as
`system/system/etc/pam.d/swaylock` and lands in `/etc/pam.d/swaylock` with the
rest of `system/system` (`setup.sh` copies the tree onto `/`). The package
`swaylock-effects` lists that file as a pacman backup file, so upgrades write a
`.pacnew` instead of overwriting it.

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

**The pre-scan script needs two routes, and their order matters.** PAM callers
differ in two independent ways, and getting either wrong produces a confusing
failure:

*What they can see.* `polkit-agent-helper@.service` runs with
`ProtectHome=yes`, so `/root/.config` — where `linux-enable-ir-emitter` keeps
its config — does not exist there. A direct call silently does nothing and the
scan sees a dark frame, while identical code works fine under `sudo`, which has
no sandbox.

*Who they run as.* **`pam_exec` runs its command with the REAL user ID**, not
the effective one, unless you pass `seteuid`. Under `sudo` that is `nova`;
under `polkit-agent-helper` it is `root`. So `systemctl start` on a system unit
is unprivileged under `sudo` and needs polkit authorization — which pops an
authentication dialog **on every single sudo**. That is dangerous, not just
annoying: three cancelled or failed dialogs faillock the account.

So `howdy-ir-pre` branches on whether it can read the config:

- **readable** → call the tool directly. Fine unprivileged, because the config
  is world-readable and the user is in the `video` group.
- **unreadable** → inside polkit's sandbox, where the caller is root, so
  `systemctl start` runs the unit outside the sandbox without prompting.

Do not branch on the tool's exit code: `linux-enable-ir-emitter run` returns 0
even when its config is missing.

### Bonus gotcha: `HOME` must be set

`linux-enable-ir-emitter` expands `$HOME` when building its log file path and
hard-fails if the variable is missing:

```
Error: failed to expend shell variable in log file path
Caused by: error looking key 'HOME' up: environment variable not found
```

Neither systemd units nor PAM provide `HOME`. That is why both the service
and the pre-scan script set `HOME=/root` explicitly.

Its config lives at `/root/.config/linux-enable-ir-emitter.toml`, but note that
`/root`, `/root/.config` and the file itself are all world-readable on this
system, which is what lets the pre-scan script apply the control unprivileged.
Only *writing* the config needs root.

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

Run from `~/.dotfiles` — the paths below are relative to it. The full
contents are reproduced under "File contents" at the end, so this works even
without the repo.

```sh
cd ~/.dotfiles

sudo cp system/system/etc/udev/rules.d/99-ir-camera-power.rules /etc/udev/rules.d/
sudo cp system/system/etc/systemd/system/linux-enable-ir-emitter.service /etc/systemd/system/
sudo install -m 755 system/system/usr/local/bin/howdy-ir-pre /usr/local/bin/howdy-ir-pre

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
| `no_confirmation` | `false` | `true` | Suppresses "Face matched user nova" on every sudo |

Stock howdy is chatty on a terminal. A plain `sudo ls` prints a verification
notice, a timing report, and a match confirmation. To keep sudo clean:

```sh
sudo sed -i -e 's/^detection_notice = .*/detection_notice = false/' \
            -e 's/^no_confirmation = .*/no_confirmation = true/' \
            -e 's/^end_report = .*/end_report = false/' /etc/howdy/config.ini
```

`detection_notice` and `end_report` are the diagnostics to turn back **on**
when something misbehaves — they report frames searched, dark frames ignored,
and the winning match score.

### The OpenCV warnings cannot be suppressed

Every face auth prints two lines to the terminal, sharing the `Password:` line:

```
[ WARN:0@0.004] global net_impl_backend.cpp:345 setPreferableTarget Targets are not supported by the new graph engine for now
```

They come from OpenCV 5's DNN engine inside `howdy-auth-helper`, not from
howdy, so no howdy setting affects them. Do not spend time on this — these
were all tried and all failed:

- `OPENCV_LOG_LEVEL=SILENT` exported in the shell: `sudo` sanitizes its own
  environment before PAM runs, so it never arrives. (The variable *is*
  correct — `sudo env OPENCV_LOG_LEVEL=SILENT howdy test` silences the CLI.)
- `OPENCV_FORCE_DNN_ENGINE=classic`: no effect, wrong value or unsupported.
- `pam_env.so conffile=...` ahead of `pam_howdy`: `pam_howdy` reads PAM's
  environment for its own use but does not forward it to the setuid helper it
  spawns.
- Wrapping the helper: impossible, it is setuid and Linux ignores setuid on
  scripts.

The fix belongs upstream. The lines are cosmetic and harmless.

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

**The `swaylock` lock screen needs more.** Its own howdy lines must come before
`system-auth` — see "Swaylock lock screen" below.

`ly` needs no extra setup beyond this file. It is a TTY greeter, so
`pam_howdy`'s native mode has the real terminal it requires.

**polkit needs a running authentication agent**, or nothing prompts at all and
`pkexec` from a non-terminal process just fails. `startup.kdl` used to spawn
`mate-polkit`, which is not installed, so the spawn failed silently and there
was no agent for months. It now spawns the installed one:

```
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
```

Check with `busctl` or simply run the agent by hand — "An authentication agent
already exists for the given subject" means one is registered.

### Careful: faillock

`pam_faillock preauth` is `required` and sits **above** `pam_howdy` in the
stack. Three failed password attempts at any polkit or sudo prompt lock the
account for 10 minutes, and **face auth cannot rescue you** — PAM treats the
stack as failed once a `required` module fails, no matter what a later
`sufficient` module returns.

Inspect and clear from a root shell:

```sh
faillock --user nova
faillock --user nova --reset
```

Keep a root shell open when experimenting with auth. This is the failure mode
that actually bites.

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
  but a Wayland lock screen does not. Without the `input` fallback, a GUI prompt
  can match your face and then sit there waiting on its password field, because
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

## Swaylock lock screen

The lock screen is the one target that needs its own configuration.

### Why it needs its own howdy lines

**`workaround=native-input` breaks face auth in a GUI lock screen.**
`system-auth` carries it for `sudo`, but in `swaylock` howdy scans in the
background while the password prompt runs, and `swaylock` answers that prompt
at once with whatever was typed before Enter. `pam_unix` then fails before the
scan finishes.

The fix is a lock-screen stack whose own `pam_howdy` line carries no
`workaround=`. Howdy then blocks: Enter on an empty field scans the face.
Because `pam_howdy` is `sufficient`, a match short-circuits the stack and
`pam_unix` never prompts. A failed scan falls through to `login`, which
asks for the password as usual.

**The file must exist.** `/etc/pam.d/swaylock` was once a symlink to the
DankMaterialShell PAM file. When that shell was removed the link dangled, PAM
fell back to `other` (`pam_deny`) and every password failed.

### Install the lock-screen config

`system/system/etc/pam.d/swaylock` is copied by `setup.sh` with the rest of
the tree. To install it alone:

```sh
cd ~/.dotfiles
sudo install -m 644 -o root -g root \
  system/system/etc/pam.d/swaylock /etc/pam.d/swaylock
```

Do this **after** step 5, so `system-auth` (reached through `login`) already
holds the howdy lines.

---

## Verify

```sh
sudo -k && sudo true        # expect: "Face matched user nova"
```

Then, at the machine:

- Lock with Mod+Shift+L, press Enter on the empty field and look at the
  camera. The scan takes a few seconds.
- Reboot and wait at the `ly` greeter instead of typing. This doubles as the
  reboot-persistence test for the udev rule and the emitter service.
- Trigger any GUI privilege prompt for polkit.

Useful during any of these — howdy logs every verdict:

```sh
journalctl --since "-3min" | grep -iE "howdy|swaylock|pam_"
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
| Lock screen: password fails before the scan ends | `workaround=` on the lock screen's own `pam_howdy` line | Remove the option from `/etc/pam.d/swaylock` |
| Lock screen: every password fails | `/etc/pam.d/swaylock` missing or a dangling link, so PAM uses `other` | Reinstall it from `system/system/etc/pam.d/swaylock` |
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

Note the route order — see "The pre-scan script needs two routes" above. Putting
`systemctl` first pops a polkit dialog on every sudo.

```sh
#!/bin/sh
# Re-apply the IR emitter UVC control immediately before a Howdy face scan.
# The camera drops this control on its own; without it every scan sees a dark frame.
#
# PAM callers differ in what they can see, and pam_exec runs us with the REAL uid
# (nova under sudo, root under polkit-agent-helper), so pick the route per caller:
#
#   config readable  -> call the tool directly. Works unprivileged: the config is
#                       world-readable and nova is in the video group.
#   config invisible -> polkit-agent-helper@.service runs with ProtectHome=yes, so
#                       /root is not there. Ask systemd, which runs the unit outside
#                       the sandbox. Only reached with a root real uid, so this does
#                       not trigger a polkit prompt of its own.
#
# Do NOT reorder these. Calling systemctl first pops a polkit authentication dialog
# on every sudo, because starting a system unit as nova needs authorization.
CONF=/root/.config/linux-enable-ir-emitter.toml

if [ -r "$CONF" ]; then
    HOME=/root exec /usr/bin/linux-enable-ir-emitter run >/dev/null 2>&1
fi

exec systemctl start linux-enable-ir-emitter.service >/dev/null 2>&1
```

### `/etc/pam.d/swaylock` (mode 644, root:root)

Note `pam_howdy.so` carries **no** `workaround=` option here, unlike in
`system-auth`.

```
#%PAM-1.0
# Face first, then the stock chain: login -> system-local-login -> system-login -> system-auth.
# Was a symlink to /etc/pam.d/dankshell; once DankMaterialShell was removed the
# link dangled, PAM fell back to `other` (pam_deny) and every password failed.
#
# Own pam_howdy line WITHOUT workaround=: system-auth's workaround=native-input scans
# in the background while the password prompt runs, but swaylock answers that prompt
# instantly with whatever was typed before Enter, so pam_unix failed before the face
# scan finished. With no workaround Howdy blocks: Enter on an empty field scans the face.
auth optional   pam_exec.so quiet /usr/local/bin/howdy-ir-pre
auth sufficient pam_howdy.so
auth include    login
```
