# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ common, config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.substituters = common.cacheSubstituters;
  nix.settings.trusted-public-keys = common.trustedPublicKeys;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "home-server"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # Set your time zone.
  time.timeZone = "America/Indiana/Indianapolis";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${common.username}" = {
    isNormalUser = true;
    description = "Benjamin Duggan";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = common.authorizedKeys;
    packages = with pkgs; [
      #  firefox
      #  thunderbird
    ];
  };

  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = common.username;
  nixpkgs.config.allowUnfree = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Set up files/dirs for vaultwarden to work
  systemd.tmpfiles.rules = [
    "d /etc/vault 755 ${config.systemd.services.vaultwarden.serviceConfig.User} ${config.systemd.services.vaultwarden.serviceConfig.Group}"
    "f /etc/default/vaultwarden 755 ${config.systemd.services.vaultwarden.serviceConfig.User} ${config.systemd.services.vaultwarden.serviceConfig.Group}"
  ];

  services.vaultwarden = {
    enable = true;
    environmentFile = "/etc/default/vaultwarden"; # extra secrets in here for email
    config = {
      ROCKET_ADDRESS = "0.0.0.0";
      DOMAIN = "https://vault.digdug.dev";
      SIGNUPS_ALLOWED = false;
      SENDS_ALLOWED = true;
      EMERGENCY_ACCESS_ALLOWED = true;
      ORG_EVENTS_ENABLED = true;
      SIGNUPS_VERIFY = true;
      INVITATIONS_ALLOWED = true;
      PASSWORD_ITERATIONS = 600000;
      PASSWORD_HINTS_ALLOWED = false;
      WEBSOCKET_ENABLED = false;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = common.stateVersion;


  # enable tailscale and use as exit node
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  systemd.services = {
    backup-vault = {
      path = [ pkgs.gnutar pkgs.sqlite pkgs.gzip ];
      script = ''
        PREFIX=`date -u +%Y-%m-%d-%H-%M`
        DATA_FOLDER=/var/lib/bitwarden_rs
        BACKUP_FOLDER=/etc/vault/backups/staging
        mkdir -p $BACKUP_FOLDER

        if [[ ! -f "$DATA_FOLDER"/db.sqlite3 ]]; then
          echo "Could not find SQLite database file '$DATA_FOLDER/db.sqlite3'" >&2
          exit 1
        fi

        ${pkgs.sqlite}/bin/sqlite3 "$DATA_FOLDER"/db.sqlite3 ".backup '$BACKUP_FOLDER/db.sqlite3'"
        cp -r "$DATA_FOLDER"/attachments "$BACKUP_FOLDER"
        cp -r "$DATA_FOLDER"/sends "$BACKUP_FOLDER"
        cp -r "$DATA_FOLDER"/icon_cache "$BACKUP_FOLDER"

        # Used to sign JWTs of logged in users. Deleting logs out users
        # cp "$DATA_FOLDER"/rsa_key.{der,pem,pub.der} "$BACKUP_FOLDER"

        ${pkgs.gnutar}/bin/tar czf "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" $BACKUP_FOLDER
        rm -rf $BACKUP_FOLDER
      '';
      serviceConfig = {
        inherit (config.systemd.services.vaultwarden.serviceConfig) User;
        Type = "oneshot";
      };
      startAt = "*-*-* 02:00:00";
    };
  };
}
