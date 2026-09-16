{ config, lib, ... }:

let
  cfg = config.services.calibre-web;
in
{
  options.services.calibre-web.libraryDir = lib.mkOption {
    type = lib.types.path;
    description = "Directory containing the Calibre library and metadata.db.";
    example = "/mnt/massive/books/calibre/cl";
  };

  config = lib.mkIf cfg.enable {
    services.calibre-web = {
      listen.ip = "0.0.0.0";
      options = {
        calibreLibrary = cfg.libraryDir;
        enableBookUploading = true;
      };
    };

    systemd.tmpfiles.settings."10-calibre-web".${cfg.libraryDir}.d = {
      mode = "0750";
      user = cfg.user;
      group = cfg.group;
    };

    systemd.services.calibre-web = {
      unitConfig.RequiresMountsFor = [ cfg.libraryDir ];
      serviceConfig.ReadWritePaths = [
        "/var/lib/calibre-web"
        cfg.libraryDir
      ];
    };
  };
}
