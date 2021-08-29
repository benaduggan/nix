# nix

[![uses nix](https://img.shields.io/badge/uses-nix-%237EBAE4)](https://nixos.org/)

_my nixpkgs folder_

## install

```bash
# install nix
curl -L https://nixos.org/nix/install | sh

# configure nix to use more cpu/ram when building
mkdir -p ~/.config/nix/ ~/.config/nixpkgs/
echo 'max-jobs = auto' >>~/.config/nix/nix.conf

# Add necessary nix channels
nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --add https://github.com/kwbauson/cfg/archive/main.tar.gz kwbauson-cfg
nix-channel --update
nix-shell '<home-manager>' -A install

# pull repo
cd ~
git clone git@github.com:benaduggan/nix.git .
rm -rf /home/$USER/.config/nixpkgs
ln -s /home/$USER/nixpkgs /home/$USER/.config/nixpkgs

# move unneeded files
mv ~/.bash_history ~/.bash_history.old
mv ~/.bash_profile ~/.bash_profile.old
mv ~/.bashrc ~/.bashrc.old
mv ~/.dir_colors ~/.dir_colors.old
mv ~/.nix-profile ~/.nix-profile.old
mv ~/.profile ~/.profile.old
mv ~/.sqliterc ~/.sqliterc.old
mv ~/.gitconfig ~/.gitconfig.old
mv ~/.tmux.conf ~/.tmux.conf.old

# enable home-manager and build packages
home-manager switch
```
