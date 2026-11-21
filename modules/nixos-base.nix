{ common, inputs, lib, ... }:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    ./alloy.nix
    ./ca-blacklist.nix
    ./node-exporter.nix
    ./openssh.nix
    ./pipewire.nix
    ./socks-proxy.nix
    ./tailscale.nix
    ./vscode-server.nix
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ inputs.self.overlays.default ];
  };

  nix.settings = common.nixSettings;

  programs.nix-ld.enable = lib.mkDefault true;
  services.openssh.enable = lib.mkDefault true;
  services.alloy.enable = lib.mkDefault true;

  age.identityPaths = lib.mkDefault [ "/home/${common.username}/.ssh/id_ed25519" ];

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs
    [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ]
    (_: lib.mkDefault "en_US.UTF-8");

  system.stateVersion = lib.mkDefault common.stateVersion;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
