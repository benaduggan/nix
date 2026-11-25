{ common, inputs, lib, ... }:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.ncro.nixosModules.default
    ./alloy.nix
    ./ca-blacklist.nix
    ./ncro.nix
    ./node-exporter.nix
    ./openssh.nix
    ./pipewire.nix
    ./socks-proxy.nix
    ./tailscale.nix
    ./vscode-server.nix
    ./watchdog.nix
  ];

  nix = {
    settings = common.nixSettings;
    registry = lib.mkIf common.isMinimal (lib.mkForce { });
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };
    optimise = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault [ "weekly" ];
    };
  };

  documentation.nixos.enable = lib.mkDefault (!common.isMinimal);

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
