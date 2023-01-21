# Bootstrapping

I didn't really do a good job of keeping track of what I did here, but I did follow this video
https://www.youtube.com/watch?v=KJgN0lnA5mk

as well as these files (heavily modified in this repo)
https://gist.github.com/jmatsushita/5c50ef14b4b96cb24ae5268dab613050#file-configuration-nix

# Daily use

Now I should be able to just edit the files within this directory

To update the system, run

```
darwin-rebuild switch --flake ~/cfg/machines/paper/
```

# Things to remember

The interesting thing about this setup so far is the building of the flake and switching to the flake seems to get rid of a lot of the steps in the overall readme about making the nixpkgs directory and symlinking it and stuff? I don't fully understand it still, but I like it.

Also got rid of ~/.config/nix cause that's managed in darwin-configuration.nix


# Manual things
* You have to install brew manually still
* you have to install this `xcode-select --install`

# TODO

- Figure out how to not duplicate home.nix memes
- Figure out how to manage homebrew with nix
- Learn flakes for real
- disable check for slack bolt by overlaying on top of Cobi's package thing with `pythonPackageOverlay`
