final: _prev:
let
  mkGitHubReleaseUpdater = final.callPackage ./mk-github-release-updater.nix { };
  customPkgs = {
    jet-terminal = final.callPackage ./jet-terminal.nix { inherit mkGitHubReleaseUpdater; };
    jetmux = final.callPackage ./jetmux.nix { inherit mkGitHubReleaseUpdater; };
  };
  updaters = final.lib.filterAttrs (_: drv: drv ? passthru.updateScript) customPkgs;
in
customPkgs // {
  update-pkgs = final.writeShellApplication {
    name = "update-pkgs";
    text = final.lib.concatStringsSep "\n" (
      final.lib.mapAttrsToList (_: drv: drv.passthru.updateScript) updaters
    );
  };
}
