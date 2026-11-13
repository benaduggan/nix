# nixpkgs' patchelf 0.19.2 corrupts VS Code's bundled Node.js executable when
# auto-fix-vscode-server rewrites its interpreter/rpath, which breaks remote
# development. Build the service's package against patchelf 0.15.2 instead.
# Drop this once nixpkgs ships a patchelf that behaves.
{ vscode-server }:
{ config, pkgs, lib, ... }:
let
  cfg = config.services.vscode-server;

  patchelf = pkgs.patchelf.overrideAttrs (_: {
    version = "0.15.2";
    src = pkgs.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  });

  autoFixVscodeServer = pkgs.callPackage "${vscode-server}/pkgs/auto-fix-vscode-server.nix"
    ((builtins.removeAttrs cfg [ "enable" ]) // { inherit patchelf; });
in
lib.mkIf cfg.enable {
  systemd.user.services.auto-fix-vscode-server.serviceConfig.ExecStart =
    lib.mkForce "${autoFixVscodeServer}/bin/auto-fix-vscode-server";
}
