{ common, config, lib, ... }:
let
  hostLabel =
    if config.services.alloy.hostLabel != null
    then config.services.alloy.hostLabel
    else config.networking.hostName;
  lokiUrl = inherit (config.services.alloy) lokiUrl;
in
{
  options.services.alloy.hostLabel = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Override the host label sent to Loki. Defaults to networking.hostName.";
  };

  options.services.alloy.lokiUrl = lib.mkOption {
    type = lib.types.str;
    default = "http://home-server-1:${toString common.ports.loki}/loki/api/v1/push";
    description = "Loki push URL.";
  };

  config = lib.mkIf config.services.alloy.enable {
    systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "adm" "systemd-journal" ];
    environment.etc."alloy/config.alloy".text = ''
      loki.write "default" {
        endpoint {
          url = "${lokiUrl}"
        }
      }

      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
      }

      loki.source.journal "systemd" {
        max_age        = "12h"
        format_as_json = true
        relabel_rules  = loki.relabel.journal.rules
        forward_to     = [loki.write.default.receiver]
        labels         = {
          job  = "systemd-journal",
          host = "${hostLabel}",
        }
      }
    '';
  };
}
