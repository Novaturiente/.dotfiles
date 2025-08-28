sudo cp ../system/etc/tlp.conf /etc/tlp.conf
sudo cp ../system/etc/greetd/config.toml /etc/greetd/config.toml
sudo cp ../system/etc/modprobe.d/nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf
sudo cp ../system/etc/modules-load/ntsync.conf /etc/modules-load.d/ntsync.conf

stow -t ~ ../nova

sudo systemctl enable greetd
