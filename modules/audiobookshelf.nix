{ config, lib, ... }:

let
  cfg = config.services.audiobookshelf;
in
{
  options.services.audiobookshelf.libraryDir = lib.mkOption {
    type = lib.types.path;
    description = "Directory containing the Audiobookshelf media library.";
    example = "/mnt/massive/books/audiobookshelf";
  };

  config = lib.mkIf cfg.enable {
    services.audiobookshelf.host = "0.0.0.0";

    systemd.tmpfiles.settings."10-audiobookshelf".${cfg.libraryDir}.d = {
      mode = "0750";
      inherit (cfg) user group;
    };

    # The library directory still needs to be selected in Audiobookshelf's UI.
    systemd.services.audiobookshelf = {
      unitConfig.RequiresMountsFor = [ cfg.libraryDir ];
      serviceConfig.ReadWritePaths = [ cfg.libraryDir ];
    };
  };
}
