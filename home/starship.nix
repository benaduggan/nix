_:
let
  symbol = "ᛥ";
in
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[${symbol}](bright-green)";
        error_symbol = "👀";
      };
      golang = {
        style = "fg:#00ADD8";
        symbol = "go ";
      };
      directory.style = "fg:#d442f5";
      nix_shell = {
        pure_msg = "";
        impure_msg = "";
        format = "via [$symbol$state]($style) ";
      };
      kubernetes = {
        disabled = false;
        style = "fg:#326ce5";
      };

      # disabled plugins
      aws.disabled = true;
      gcloud.disabled = true;
      package.disabled = true;
    };
  };
}
