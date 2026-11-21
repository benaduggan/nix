{ lib, ... }:
{
  services.tailscale = {
    enable = lib.mkDefault true;
    # Configures IP forwarding + loose rp_filter so every host can act as or use
    # an exit node; actual exit-node approval is controlled in the admin console.
    useRoutingFeatures = lib.mkDefault "both";
    extraSetFlags = lib.mkDefault [ "--advertise-exit-node" ];
  };
}
