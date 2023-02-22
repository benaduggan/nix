# nix

[![uses nix](https://img.shields.io/badge/uses-nix-%237EBAE4)](https://nixos.org/)

_my nixpkgs folder_

## install

```bash
# install nix
curl -L https://nixos.org/nix/install | sh

install git
generate ssh key and add it to your profile

# configure nix to use more cpu/ram when building
mkdir -p ~/.config/nix/
echo 'max-jobs = auto' >>~/.config/nix/nix.conf
echo 'experimental-features = nix-command flakes' >>~/.config/nix/nix.conf


# pull repo
cd ~
REPO_DIR="cfg"
git clone git@github.com:benaduggan/nix.git "$REPO_DIR"

make a new dir in the machines for the new machine
do the things it needs for configuring
- cp the hardware config
- edit some configs

make a new block in flake.nix for the new machine

nixos-rebuild build --flake .#{new machine}
if it works, switch!

```

# Homebrew

nix darwin does not install homebrew, you gotta do that yourself still!

this is what you'd need to do to get the brew command added to your path, but idk if you want to do that since you'd want everything to be managed by nix anyway?

```
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/bduggan/.bash_profile
```
