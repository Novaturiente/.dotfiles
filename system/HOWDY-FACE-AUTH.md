# Face Login (Howdy + IR camera)

Windows-Hello-style face authentication on this laptop, using the built-in
**infrared** camera — not the RGB one. Covers `sudo`, the `ly` greeter, the
`dms` lock screen, and polkit prompts.

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

```sh
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

`sface_threshold` (the actual face-match strictness) is left at its default of
`0.6942`. Loosening *that* would be the setting that weakens security.

Models are stored in `/etc/howdy/models/`. Manage with `howdy list`,
`howdy add`, `howdy remove`, `howdy clear`.

### 5. PAM

**Open a second terminal with `sudo -i` and leave it there before editing PAM.**
A mistake here can lock you out of authentication entirely.

Every relevant service funnels into a single file, so one edit covers all four
targets:

- `sudo` → `system-auth`
- `ly` → `login` → `system-local-login` → `system-login` → `system-auth`
- `dms` lock screen → `system-auth` directly
- polkit → `/usr/lib/pam.d/polkit-1` → `system-auth`

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

## Verify

```sh
sudo -k && sudo true        # expect: "Face matched user nova"
```

Then, at the machine:

- Lock with `dms ipc call lock lock` and look at the camera. Leave the password
  field **empty** — the injected Enter only submits an empty prompt.
- Reboot and wait at the `ly` greeter instead of typing. This doubles as the
  reboot-persistence test for the udev rule and the emitter service.
- Trigger any GUI privilege prompt for polkit.

Recovery if the greeter misbehaves: `Ctrl+Alt+F2` to a TTY, log in with your
password, restore the backup.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `All frames were too dark`, darkness 85+ | Emitter not firing, or you are backlit | Check `power/control` is `on`; run `linux-enable-ir-emitter run` manually and re-test |
| Works once, fails after | The `pam_exec` pre-scan hook is missing or not executable | `sudo /usr/local/bin/howdy-ir-pre` should exit 0 silently |
| `failed to expend shell variable` | `HOME` unset | Confirm `Environment=HOME=/root` in the unit, `HOME=/root` in the script |
| Face matches but lock screen hangs | `workaround=native` instead of `native-input` | Change the `pam_howdy.so` line |
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
