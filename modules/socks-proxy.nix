{ config, lib, ... }:
{
  config = lib.mkIf config.services._3proxy.enable {
    services._3proxy.services = lib.mkDefault [{
      type = "socks";
      bindPort = 1080;
      auth = [ "none" ];
    }];
  };
}
