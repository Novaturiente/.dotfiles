# Necessary Packages (Dependencies of Your Listed Packages)

These packages **are not in your package list** but **are required** by packages that *are* in your list. **Do not remove** them, or the depending package will break.

---

## Required by packages in your list (keep these)

| Package | Required by (from your list) |
|--------|-------------------------------|
| **accountsservice** | dms-shell-git |
| **bluez** | blueman |
| **bluez-libs** | blueman |
| **device-mapper** | docker |
| **hdparm** | tlp |
| **noto-fonts** | zen-browser-bin |
| **perl** | git, stow, tlp |
| **python** | flatpak, git-filter-repo, meson, python-pyflakes, python-pynvim, python-ruff, python-tldextract, tlp-pd, trash-cli, udiskie |
| **rtkit** | xdg-desktop-portal |
| **sudo** | base-devel |
| **texinfo** | base-devel |
| **ttf-bitstream-vera** | zen-browser-bin |
| **ttf-dejavu** | zen-browser-bin |
| **ttf-liberation** | google-chrome, zen-browser-bin |
| **usbutils** | tlp |
| **which** | base-devel |

---

## Required by system/base (do not remove)

| Package | Required by |
|--------|-------------|
| **cryptsetup** | systemd, libblockdev-crypto, volume_key |
| **device-mapper** | cryptsetup, docker, lvm2, nfs-utils, xfsprogs, dmraid, parted |
| **diffutils** | mkinitcpio |
| **e2fsprogs** | bind, fsarchiver, nfs-utils, libblockdev-fs |
| **less** | man-db |
| **mkinitcpio** | linux |
| **sudo** | base-devel |

---

## Required only by other “unnecessary” packages

If you remove the dependent package, these become optional:

| Package | Required by (not in your list) |
|--------|--------------------------------|
| **lsb-release** | anydesk-bin |
| **plymouth** | cachyos-plymouth-bootanimation |
| **intel-media-driver** | vpl-gpu-rt |
| **opencl-mesa** | lib32-opencl-mesa |
| **vulkan-intel** | lib32-vulkan-intel |
| **xorg-xrandr** | xorg-xinput |
| **sysfsutils** | lsscsi |

---

## Bluetooth stack (needed by blueman)

- **bluez** – required by blueman  
- **bluez-libs** – required by blueman  
- **bluez-hid2hci** – no “Required By”; likely optional or pulled for Bluetooth support. Safe to treat as part of the Bluetooth stack; keep if you use blueman.

---

## Summary

**Do not remove:**  
accountsservice, bluez, bluez-libs, device-mapper, hdparm, noto-fonts, perl, python, rtkit, sudo, texinfo, ttf-bitstream-vera, ttf-dejavu, ttf-liberation, usbutils, which, cryptsetup, diffutils, e2fsprogs, less, mkinitcpio.

**Optional (only needed by packages you might uninstall):**  
lsb-release, plymouth, intel-media-driver, opencl-mesa, vulkan-intel, xorg-xrandr, sysfsutils.
