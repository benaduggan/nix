# nix

[![uses nix](https://img.shields.io/badge/uses-nix-%237EBAE4)](https://nixos.org/)

_my nixpkgs folder_

## install

```bash
# install nix if not nixos
curl -L https://nixos.org/nix/install | sh

# configure nix to use more cpu/ram when building and enable flakes
mkdir -p ~/.config/nix/
echo 'max-jobs = auto' >>~/.config/nix/nix.conf
echo 'experimental-features = nix-command flakes' >>~/.config/nix/nix.conf

# install git if it's not installed

# pull repo
cd ~
REPO_DIR="cfg"
git clone git@github.com:benaduggan/nix.git "$REPO_DIR"

# uninstall git because we'll install it with home-manager

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

# SSH Keys

All my important public keys are associated with my github, so you can pull them by curling them to the right file

```bash
curl https://github.com/benaduggan.keys -o ~/.ssh/authorized_keys
```

# Flake Way


