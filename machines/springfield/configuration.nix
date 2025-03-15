{ pkgs, common, config, lib, ... }:
let
  hostName = common.machineName;
in
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
  boot.loader.efi.efiSysMountPoint = "/boot";
  programs.nix-ld.enable = true;

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
  # services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  # services.xserver = {
  #   xkb.layout = "us";
  #   xkb.variant = "";
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  services.pulseaudio.enable = false;
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;


  # enable tailscale and use as exit node
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ common.username ];
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "US/Eastern";
      image = "ghcr.io/home-assistant/home-assistant:2024.8.1";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      positions.filename = "/tmp/positions.yaml";
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      clients = [{
        url = "http://home-server-1:3100/loki/api/v1/push";
      }];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
      ];
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


  # migration vaultwarden to springfield while we move
  age = {
    identityPaths = [ "/home/bduggan/.ssh/id_ed25519" ];
    secrets = {
      vaultwarden.file = ../../secrets/vaultwarden.age;
    };
  };

  # Set up files/dirs for vaultwarden to work
  systemd.tmpfiles.rules = [
    "d /etc/vault 755 ${config.systemd.services.vaultwarden.serviceConfig.User} ${config.systemd.services.vaultwarden.serviceConfig.Group}"
    "f /etc/default/vaultwarden 755 ${config.systemd.services.vaultwarden.serviceConfig.User} ${config.systemd.services.vaultwarden.serviceConfig.Group}"
  ];

  services.vaultwarden = {
    enable = true;
    environmentFile = config.age.secrets.vaultwarden.path; # extra secrets in here for email
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
      PASSWORD_HINTS_ALLOWED = true;
      WEBSOCKET_ENABLED = true;
    };
  };

  services._3proxy = {
    enable = true;
    services = [{
      type = "socks";
      bindPort = 1080;
      auth = [ "none" ];
    }];
  };

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

        # Used to sign JWTs of logged in users. Deleting logs out users
        # cp "$DATA_FOLDER"/rsa_key.{der,pem,pub.der} "$BACKUP_FOLDER"

        ${pkgs.gnutar}/bin/tar czf "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" $BACKUP_FOLDER
        ${pkgs.openssh}/bin/scp -o UserKnownHostsFile=/home/${common.username}/.ssh/known_hosts -i /home/${common.username}/.ssh/id_ed25519 "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" ${common.username}@bduggan-desktop:/mnt/bigboi/vault-backups-springfield/
        ${pkgs.openssh}/bin/scp -o UserKnownHostsFile=/home/${common.username}/.ssh/known_hosts -i /home/${common.username}/.ssh/id_ed25519 "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" ${common.username}@home-server-1:/home/bduggan/vault-backups-springfield/

        rm -rf $BACKUP_FOLDER
      '';
      serviceConfig = {
        User = "root";
        Type = "oneshot";
      };
      startAt = "*-*-* 02:00:00";
    };
  };
}
