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
  programs.nix-ld.enable = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  networking.hostName = "home-server"; # Define your hostname.

  age = {
    identityPaths = [ "/home/bduggan/.ssh/id_ed25519" ];
    secrets = {
      grafana.file = ../../secrets/grafana.age;
      vaultwarden.file = ../../secrets/vaultwarden.age;
      ondeck.file = ../../secrets/ondeck-vars.age;

      magicRunnerToken = {
        file = ../../secrets/home-magic-runner.age;
        mode = "644";
      };
      homeRunnerToken = {
        file = ../../secrets/home-self-runner.age;
        mode = "644";
      };
    };
  };
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
  services.xserver.enable = false;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = false;
  services.xserver.desktopManager.gnome.enable = false;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
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

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = common.username;
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

        # Used to sign JWTs of logged in users. Deleting logs out users
        # cp "$DATA_FOLDER"/rsa_key.{der,pem,pub.der} "$BACKUP_FOLDER"

        ${pkgs.gnutar}/bin/tar czf "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" $BACKUP_FOLDER
        ${pkgs.openssh}/bin/scp -o UserKnownHostsFile=/home/${common.username}/.ssh/known_hosts -i /home/${common.username}/.ssh/id_ed25519 "/etc/vault/backups/$PREFIX-vault-backup.tar.gz" ${common.username}@bduggan-desktop:/mnt/bigboi/vault-backups/

        rm -rf $BACKUP_FOLDER
      '';
      serviceConfig = {
        User = "root";
        Type = "oneshot";
      };
      startAt = "*-*-* 02:00:00";
    };

    engineer-on-deck = {
      path = [ pkgs.gawk pkgs.gnugrep pkgs.curlMinimal ];
      script = ''
        # get the google sheet url and slack webhook url from secrets
        export $(${pkgs.gnugrep}/bin/grep -v '^#' ${config.age.secrets.ondeck.path} | xargs)

        TMP_PATH=schedule.csv
        TODAY=`date +"%-m/%-d/%Y"` # get the date without leading 0s
        curl -L $GOOGLE_PUBLIC_URL -o $TMP_PATH
        SLACK_ID=`cat $TMP_PATH | grep $TODAY | awk -F, '{print $3}'` # get the slack id from todays row
        JSON='{"slack_user_id": "'$SLACK_ID'"}'
        rm $TMP_PATH
        curl -X POST -H "Content-type: application/json" -d "$JSON" $SLACK_WEBHOOK_URL
      '';
      serviceConfig = {
        User = "root";
        Type = "oneshot";
      };
      startAt = "Mon..Fri 09:50";
    };

    greenhouse-service =
      let
        myPython = pkgs.python311.withPackages (p: with p; [
          requests
        ]);
      in
      {
        path = [ myPython ];
        wantedBy = [ "multi-user.target" ];
        script = ''python /home/bduggan/greenhouse-passthrough/server.py'';
      };
  };

  # docker stuff
  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ common.username ];
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "US/Eastern";
      image = "ghcr.io/home-assistant/home-assistant:2024.5.0";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secrets.grafana.path;
  services.grafana = {
    enable = true;
    settings = {
      security.allow_embedding = true;
      smtp.enabled = true;
      server = {
        domain = "grafana.digdug.dev";
        http_port = common.ports.grafana;
        http_addr = "0.0.0.0";
      };
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString common.ports.prometheus}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://localhost:${toString common.ports.loki}";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    port = common.ports.prometheus;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = common.ports.prometheus_node_exporter;
      };
    };
    scrapeConfigs = [
      {
        job_name = "Loki service";
        static_configs = [{
          targets = [ "127.0.0.1:${toString common.ports.loki}" ];
        }];
      }
      {
        job_name = "chrysalis";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
      {
        job_name = "greenhouse";
        scrape_interval = "60s";
        static_configs = [{
          targets = [ "localhost:7000" ];
        }];
      }
      {
        job_name = "circuit";
        scrape_interval = "60s";
        static_configs = [{
          targets = [ "192.168.0.216" ];
        }];
      }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      server.http_listen_port = common.ports.loki;
      auth_enabled = false;
      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2022-06-06";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };

        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        compactor_ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };
      query_scheduler.max_outstanding_requests_per_tenant = 32768;
      querier.max_concurrent = 16;
    };
  };

  services.github-runners = {
    magic = {
      enable = true;
      extraLabels = [ "nix" ];
      extraPackages = with pkgs; [ gh cachix nodejs_20 corepack_20 gnused ];
      replace = true;
      tokenFile = config.age.secrets.magicRunnerToken.path;
      url = "https://github.com/MagicSchoolAi/MagicSchoolAi/";
    };
    nix-repo = {
      enable = true;
      extraLabels = [ "nix" ];
      extraPackages = with pkgs; [ gh cachix ];
      replace = true;
      tokenFile = config.age.secrets.homeRunnerToken.path;
      url = "https://github.com/benaduggan/nix";
    };
  };
}
