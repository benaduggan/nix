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

  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ common.username ];
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      # https://github.com/home-assistant/core
      image = "ghcr.io/home-assistant/home-assistant:2025.12.5";
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "US/Eastern";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  networking.firewall.enable = false;

  # migration vaultwarden to springfield while we move
  age.secrets.vaultwarden.file = ../../secrets/vaultwarden.age;

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

  services._3proxy.enable = true;

  systemd.services = {
    backup-vault = {
      path = [ pkgs.gnutar pkgs.sqlite pkgs.gzip ];
      script = ''
        PREFIX=`date -u +%Y-%m-%d-%H-%M`
        DATA_FOLDER=/var/lib/vaultwarden
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
