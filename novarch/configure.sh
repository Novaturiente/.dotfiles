sudo cp system/etc/tlp.conf /etc/tlp.conf
sudo cp system/etc/greetd/config.toml /etc/greetd/config.toml
sudo cp system/etc/modprobe.d/nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf
sudo cp system/etc/modules-load/ntsync.conf /etc/modules-load.d/ntsync.conf

sudo systemctl enable greetd

cd ..
stow -t ~ nova

chsh -s $(which zsh)

cd

sudo cp ../nova/.config/nix/nix.conf /etc/nix/nix.conf

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

sudo systemctl enable --now nix-daemon

sudo nix run github:nix-community/home-manager -- init --switch

home-manager switch
