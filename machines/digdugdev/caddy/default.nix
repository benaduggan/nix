{ common, ... }:
{
  imports = [
    ./auth.nix
    ./public.nix
    ./tailnet-only.nix
    ./vault.nix
  ];

  systemd.services.caddy = {
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
  };

  services.caddy = {
    enable = true;
    inherit (common) email;
    package = common.jacobiLegacy._zaddy {
      plugins = p: [
        p.caddy-security
        {
          name = "github.com/caddy-dns/digitalocean";
          version = "04bde2867106aa1b44c2f9da41a285fa02e629c5";
        }
      ];
      vendorHash = "sha256-LG6StZi/TB2O1ZIS9VQ7oHp1d3QX+npmTIn4sgJIbuA=";
    };
  };
}
