#!/usr/bin/env bash
# vm.sh NAME [ISO] - boot a KVM linux VM in a GTK window.
#   Disk auto-created at ~/VMs/NAME.qcow2 on first run.
#   Pass an ISO to install; omit it afterwards to boot the disk.
#   SSH into the guest: ssh -p 2222 user@localhost
# Env overrides: VM_DIR VM_RAM VM_CPUS VM_SIZE VM_SSH_PORT
set -euo pipefail

NAME=${1:?usage: vm.sh NAME [ISO]}
ISO=${2:-}
DIR=${VM_DIR:-$HOME/VMs}
DISK=$DIR/$NAME.qcow2
RAM=${VM_RAM:-8G}
CPUS=${VM_CPUS:-8}
SIZE=${VM_SIZE:-60G}
SSH_PORT=${VM_SSH_PORT:-2222}

mkdir -p "$DIR"
[[ -f $DISK ]] || qemu-img create -f qcow2 "$DISK" "$SIZE"

args=(
	-name "$NAME"
	-enable-kvm -machine q35 -cpu host -smp "$CPUS" -m "$RAM"
	-drive file="$DISK",if=virtio,format=qcow2,cache=writeback,discard=unmap
	-nic user,model=virtio-net-pci,hostfwd=tcp::"$SSH_PORT"-:22
	-device virtio-vga -display gtk
	-device virtio-tablet-pci -device virtio-keyboard-pci
	-device virtio-balloon
)

# ponytail: SeaBIOS default. For UEFI guests add:
#   -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
#   -drive if=pflash,format=raw,file=$DIR/$NAME-vars.fd   (copy of OVMF_VARS.4m.fd)
[[ -n $ISO ]] && args+=(-cdrom "$ISO" -boot d)

exec qemu-system-x86_64 "${args[@]}"
