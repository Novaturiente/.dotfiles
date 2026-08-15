#!/usr/bin/env bash
# nixos-vm.sh [ISO] - boot the NixOS VM in a GTK window.
#   Disk:    ~/VMs/nixos.qcow2   (created at 60G on first run, never wiped by this script)
#   Serial:  telnet 127.0.0.1:4445  -> scripts/nixos-console.sh talks to this
#   Share:   ~/VMs/nixos-share  -> mount tag "hostshare" inside the guest
# Pass the installer ISO to install; omit it afterwards to boot the disk.
# Env overrides: VM_DIR VM_RAM VM_CPUS VM_SIZE VM_SERIAL_PORT
set -euo pipefail

ISO=${1:-}
DIR=${VM_DIR:-$HOME/VMs}
DISK=$DIR/nixos.qcow2
SHARE=$DIR/nixos-share
RAM=${VM_RAM:-8G}
CPUS=${VM_CPUS:-8}
SIZE=${VM_SIZE:-60G}
PORT=${VM_SERIAL_PORT:-4445}

mkdir -p "$DIR" "$SHARE"
[[ -f $DISK ]] || qemu-img create -f qcow2 "$DISK" "$SIZE"

args=(
	-name nixos
	-enable-kvm -machine q35 -cpu host -smp "$CPUS" -m "$RAM"
	-drive file="$DISK",if=virtio,format=qcow2,cache=writeback,discard=unmap
	-nic user,model=virtio-net-pci,hostfwd=tcp::2223-:22
	# virtio-vga-gl + gl=on gives the guest a virgl 3D renderer. niri skips
	# software EGL, so without this the desktop is a black screen.
	-device virtio-vga-gl -display gtk,gl=on
	-device virtio-tablet-pci -device virtio-keyboard-pci
	-device virtio-balloon
	# serial console exposed on TCP so the host can drive a shell without SSH
	-serial telnet:127.0.0.1:"$PORT",server,nowait
	# host <-> guest file drop
	-virtfs local,path="$SHARE",mount_tag=hostshare,security_model=mapped-xattr
)

# ponytail: SeaBIOS, not UEFI. NixOS installs GRUB on it fine.
# Want systemd-boot/UEFI? add the OVMF pflash pair, see scripts/vm.sh.
[[ -n $ISO ]] && args+=(-cdrom "$ISO" -boot d)

exec qemu-system-x86_64 "${args[@]}"
