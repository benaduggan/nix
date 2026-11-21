{ common, lib, ... }:
let
  hostName = common.machineName;
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/vaultwarden-replication.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  networking.hostName = hostName; # Define your hostname.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Set your time zone.
  time.timeZone = "America/Indiana/Indianapolis";

  services.pipewire.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bduggan = {
    isNormalUser = true;
    description = "Benjamin Duggan";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = common.authorizedKeys;
    # packages = with pkgs; [
    #  firefox
    #  thunderbird
    # ];
  };

  # Enable automatic login for the user.
  # services.displayManager.autoLogin.enable = true;
  # services.displayManager.autoLogin.user = "bduggan";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.vaultwardenReplication = {
    enable = true;
    role = "standby";
    secretFile = ../../secrets/vaultwarden.age;
    archiveDir = common.ardenVaultwardenArchiveDir;
  };

  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ common.username ];
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      # https://github.com/home-assistant/core
      image = "ghcr.io/home-assistant/home-assistant:2026.8.3";
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "US/Eastern";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services._3proxy.enable = true;

  networking.firewall.enable = false;
}
