{
  services.hermes-agent.instances.pooka.settings.webhook = {
    enabled = true;
    host = "0.0.0.0";
    port = 8644;
    max_body_bytes = 1048576;
    routes = {
      pebble-agent = {
        prompt = builtins.readFile ./prompts/pebble-agent.md;
        deliver = "ntfy";
      };
      pebble-search = {
        prompt = builtins.readFile ./prompts/pebble-search.md;
        deliver = "ntfy";
      };
    };
  };
}
