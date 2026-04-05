{ common, ... }:
{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "processes" ];
    port = common.ports.prometheus_node_exporter;
  };
}
