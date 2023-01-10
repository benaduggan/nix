# nix

[![uses nix](https://img.shields.io/badge/uses-nix-%237EBAE4)](https://nixos.org/)

_my nixpkgs folder_

## install

```bash
# install nix
curl -L https://nixos.org/nix/install | sh

# configure nix to use more cpu/ram when building
mkdir -p ~/.config/nix/
echo 'max-jobs = auto' >>~/.config/nix/nix.conf

# Add nix channels
nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --add https://github.com/kwbauson/cfg/archive/main.tar.gz kwbauson-cfg
nix-channel --update
nix-shell '<home-manager>' -A install # if not on nixos?

# pull repo
cd ~
REPO_DIR="cfg"
git clone git@github.com:benaduggan/nix.git "$REPO_DIR"
rm -rf /home/$USER/.config/nixpkgs
ln -s /home/$USER/"$REPO_DIR"/nixpkgs /home/$USER/.config/nixpkgs

# move unneeded files
mv ~/.bash_history ~/.bash_history.old
mv ~/.bash_profile ~/.bash_profile.old
mv ~/.bashrc ~/.bashrc.old
mv ~/.dir_colors ~/.dir_colors.old
mv ~/.profile ~/.profile.old
mv ~/.sqliterc ~/.sqliterc.old
mv ~/.gitconfig ~/.gitconfig.old
mv ~/.tmux.conf ~/.tmux.conf.old

# enable home-manager and build packages
home-manager switch
```

# Homebrew

nix darwin does not install homebrew, you gotta do that yourself still!

this is what you'd need to do to get the brew command added to your path, but idk if you want to do that since you'd want everything to be managed by nix anyway?

```
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/bduggan/.bash_profile
```
