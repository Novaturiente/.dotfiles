# Setting up novarch and novahome

Two machines, two setup scripts, one repo:

| Machine | Role | Script |
|---|---|---|
| `novarch` | Laptop, Hyprland desktop | `system/setup.sh` |
| `novahome` | Headless home server | `system/novahome/setup.sh` |

Both scripts run as `nova`, never with `sudo` (they call `sudo` themselves), and
reboot at the end. Each uses its own novarch package folder: `system/packages`
for the laptop, `system/novahome/packages` for the server. novarch reads every
top-level file in its folder, so the server would otherwise get the laptop's
desktop lists.

---

## novarch (laptop)

### Before setup.sh

1. Install CachyOS with **limine** as boot loader and **btrfs** root. Pick no
   desktop: the script installs Hyprland, niri and Ly itself.
2. Create the user `nova`, then log in on a TTY.
3. Clone the repo to `~/.dotfiles`. The `git@github.com` remote needs an SSH key
   on GitHub; without one, clone over HTTPS and switch the remote later:

   ```sh
   git clone https://github.com/Novaturiente/.dotfiles ~/.dotfiles
   git -C ~/.dotfiles remote set-url origin git@github.com:Novaturiente/.dotfiles.git
   ```

4. Run it:

   ```sh
   ~/.dotfiles/system/setup.sh
   ```

   `novarch sync` shows its plan and asks before it changes anything.

### After setup.sh

- **Tailscale:** `sudo tailscale up`. The `~/server` sshfs mount (novahome's home)
  needs it.
- **novacode:** `novacode login claude` (`settings.json` picks a claude model).
- **Boot splash and hibernate:** in `/etc/mkinitcpio.conf` the `HOOKS` need
  `plymouth` and `resume`. Hibernate also needs a swap file (for example
  `/swap/swapfile`) and `resume=` on the kernel command line, plus `quiet splash`.
  Then run `sudo limine-mkinitcpio`.
- **Face unlock for sudo and swaylock:** hand edits to `/etc/pam.d/system-auth`
  and the IR emitter setup. Follow `system/HOWDY-FACE-AUTH.md`.
- **Bitwarden face unlock (rbw + TPM):** follow `system/RBW-FACE-UNLOCK.md`.
- **hyprglass plugin:** run `~/.dotfiles/scripts/hyprglass.sh build` (again after each Hyprland upgrade);
  `hyprland.lua` loads it at startup.
- **novacode links:** `novacode install`, `mcp add` and `Always` approvals turn
  the stowed links in `~/.novacode` into real files. Check with
  `ls -l ~/.novacode` and relink if needed.

---

## novahome (server)

### What to check before reinstalling

- **`~/Homeshare` is not backed up.** It holds the media library on the internal
  NVMe. Keep the `@home` subvolume during the install, or copy it to
  `/mnt/storage` first.
- **MySQL data is not backed up**: `backup-automation.sh` excludes
  `~/Automation/mysql/data/`. Dump it before reinstalling:
  `docker exec <mysql container> mysqldump --all-databases ...`.
- Run one last backup and check that it finished:

  ```sh
  systemctl --user start backup-automation.service
  tail -3 ~/.cache/backup-automation/backup.log
  ```

  A log that shows `=== Backup started` and no end line means the USB drive hung.
- Check the USB drive UUID still matches the one `setup.sh` writes to
  `/etc/fstab`:

  ```sh
  lsblk -no UUID,MOUNTPOINT | grep /mnt/storage   # want d2a5667d-1120-49a6-8ce1-4018633fe64a
  ```

### Install and setup.sh

1. Install CachyOS with **limine**, **btrfs** root and **no desktop**. Hostname
   `novahome`, user `nova`.
2. Log in on the TTY (or over SSH from the laptop's LAN), clone the repo to
   `~/.dotfiles` (HTTPS, as above), then run:

   ```sh
   ~/.dotfiles/system/novahome/setup.sh
   ```

   It installs the packages, deletes the installer's snapper snapshots and removes
   snapper, copies `system/novahome/system/` onto `/`, adds `consoleblank=300`,
   adds `/mnt/storage` to fstab, stows the dotfiles (all except `.novacode` and
   systemd user units), installs novacode, enables linger, masks sleep, enables the
   services, sets up ufw and reboots.

### After setup.sh

Do these in order: later steps need files from the restore.

1. **Tailscale.**

   ```sh
   sudo tailscale up
   ```

2. **Restore from `/mnt/storage`.** The backups are plain rsync mirrors, so
   copying them back is enough:

   ```sh
   B=/mnt/storage
   rsync -a $B/Automation_backup/ ~/Automation/
   rsync -a $B/Immich_backup/     ~/Immich/
   rsync -a $B/Jellyfin_backup/   ~/Jellyfin/
   rsync -a $B/Vaultwarden_backup/data/ ~/Automation/vaultwarden/data/
   S=$B/home-secrets_backup
   rsync -a $S/.env ~/.env
   rsync -a $S/ssh/ ~/.ssh/
   rsync -a $S/oci/ ~/.oci/
   rsync -a $S/systemd-user/ ~/.config/systemd/user/
   rsync -a $S/kdeconnect/ ~/.config/kdeconnect/
   rsync -a $S/hermes/ ~/.hermes/
   rsync -a $S/agents/novacode/ ~/.novacode/
   rsync -a $S/agents/claude/ ~/.claude/
   chmod 700 ~/.ssh; chmod 600 ~/.env ~/.ssh/id_*
   ```

   The SQLite snapshots (Vaultwarden, OmniRoute, Sonarr, Radarr, Prowlarr) sit at
   the paths the apps expect, so the copies above put them back in place.

3. **novacode packages**, pinned by the restored lock file:

   ```sh
   jq -r 'to_entries[] | "\(.value.source)|\(.value.tag // .value.rev)"' ~/.novacode/packages.lock.json |
     while IFS='|' read -r src ref; do novacode install "$src" --ref "$ref"; done
   ```

   Then `novacode login claude` if the restored login has expired.

4. **Hermes Agent.** The checkout is not backed up, only its base commit and local
   patch. Clone the hermes-agent repo into `~/.hermes/hermes-agent`, then:

   ```sh
   cd ~/.hermes/hermes-agent
   git checkout "$(cat ../hermes-agent.HEAD)"
   git apply ../hermes-agent-local.patch
   ```

5. **Python virtualenv.** Backups skip `.venv/`. Only telegram-file-bot has one
   (it has a `pyproject.toml`):

   ```sh
   cd ~/Automation/telegram-file-bot && uv sync
   ```

6. **Docker stacks.** Start each stack:

   ```sh
   for d in ~/Automation/{9router,arr,cloudflared,gotify,mysql,nginx-proxy-manager,omniroute,opencloud,qbittorrent,redis,vaultwarden} ~/Immich ~/Jellyfin; do
     (cd "$d" && docker compose up -d)
   done
   ```

   - NPM's `letsencrypt/` folder is not backed up. Re-issue the certificates from
     the NPM UI (Cloudflare DNS-01; the token is `CLOUDFLARE_API` in `~/.env`).
   - Restore the MySQL dump made before the reinstall.

7. **User services and timers.** The restored unit files in
   `~/.config/systemd/user/` are symlinks into `~/Automation`. Enable them:

   ```sh
   systemctl --user daemon-reload
   systemctl --user enable --now backup-automation.timer device-watch.timer \
     docker-auto-update.timer home-ip-watchdog.timer kdeconnect-refresh.timer \
     lms-routing-watch.timer media-scan.timer media-torrent-import.timer \
     media-torrent-import.path weekly-cleanup.timer \
     telegram-file-bot.service tmux.service tv-watch.service tv-mpris.service \
     kdeconnect.service hermes-gateway.service hermes-relay.service \
     hermes-dashboard.service
   ```

8. **TV control** (`tv-watch`, `tv-mpris`, `kdeconnect`). The packages
   (`android-tools`, `kdeconnect`, `python-dbus`, `python-gobject`) and the
   KDE Connect ufw rule come from `setup.sh`. What's left:
   - adb identity the TV already trusts:

     ```sh
     mkdir -p ~/.android
     ln -sf ~/Automation/tv-watch/adbkey     ~/.android/adbkey
     ln -sf ~/Automation/tv-watch/adbkey.pub ~/.android/adbkey.pub
     ```

   - KDE Connect pairing (`~/.config/kdeconnect/`: device keys, trusted phone,
     the "Mirror to TV" run command) comes back with step 2's restore, so the
     phone needs no re-pairing.
   - Check: `systemctl --user status tv-watch tv-mpris kdeconnect` and
     `~/Automation/tv-watch/tv-mpris.py --selftest`.

9. **Tailscale serve** for Hermes. The three units bind loopback only, and
   `tailscale serve` adds TLS on the tailnet name:

   ```sh
   sudo tailscale serve --bg --https=8642 http://127.0.0.1:8642
   sudo tailscale serve --bg --https=8767 http://127.0.0.1:8767
   sudo tailscale serve --bg --https=9119 http://127.0.0.1:9119
   ```

   The dashboard also needs `HERMES_DASHBOARD_ALLOWED_HOSTS=novahome.tail9d0106.ts.net`
   (see `~/Automation/HOST.md`).

10. **Samba.** It won't start without a config:

    ```sh
    sudo install -m 644 ~/Automation/samba/smb.conf /etc/samba/smb.conf
    testparm -s /etc/samba/smb.conf
    sudo systemctl enable --now smb nmb
    ```

11. **Optional SSH rate limits** (not active on the old install):

    ```sh
    sudo install -m 644 ~/Automation/ssh-hardening/10-rate-limit.conf /etc/ssh/sshd_config.d/
    sudo systemctl reload sshd
    ```

12. **Docker to host ports.** ufw drops new ports from containers until allowed.
    `setup.sh` allows all of `172.16.0.0/12`. If an NPM upstream hangs for 60 s and
    then returns 504, check that rule first: `sudo ufw status`.

### Checks after the next reboot

```sh
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # suspended (RTX 2050 off)
grep -o consoleblank=300 /proc/cmdline
sysctl net.ipv4.tcp_congestion_control                        # bbr
cat /sys/kernel/mm/transparent_hugepage/enabled               # [madvise]
cat /sys/block/nvme0n1/queue/scheduler                        # [none]
findmnt /mnt/storage
systemctl --failed; systemctl --user --failed
```
