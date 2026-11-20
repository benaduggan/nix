{ pkgs, lib, common, ... }:
let
  inherit (common) isGraphical;
  tomlFormat = pkgs.formats.toml { };
  bashCmd = [ "${pkgs.bashInteractive}/bin/bash" "-l" ];
in
{
  # Deployed on all hosts (servers + desktops/laptops)
  xdg.configFile."jetmux/config.toml".source = tomlFormat.generate "jetmux-config.toml" {
    prefix = "C-b";

    keys = {
      normal = {
        # ijkl arrow-key pane navigation (matching home/tmux.nix)
        "M-h" = "none";
        "M-j" = "focus-left";
        "M-i" = "focus-up";
        "M-k" = "focus-down";
        "M-l" = "focus-right";
      };
      prefix = {
        # split with | and - (defaults), unbind " and % (matching home/tmux.nix)
        "\"" = "none";
        "%" = "none";
      };
    };

    theme.name = "Dracula+ High Contrast";
    colors.selection-background = "#796581";

    persist.interval = 300;
  };

  # Deployed on graphical hosts (macOS + NixOS graphical machines)
  xdg.configFile."jet/config.toml" = lib.mkIf isGraphical {
    source = tomlFormat.generate "jet-config.toml" {
      include = [ "~/.config/jet/local.toml" ];

      shell.command = bashCmd;

      quake = {
        hotkey = "ctrl+shift+space";
        profile = "bash";
        monitor = "primary";
        x = 0.0;
        y = 0.0;
        width = 0.5;
        height = 1.0;
        over-taskbar = false;
        always-on-top = false;
        hide-on-blur = false;
      };

      window.decorations = "custom";

      theme.name = "Dracula+ High Contrast";
      colors.selection-background = "#796581";

      status = {
        position = "tab-bar";
        segments = [
          { text = "{user}@{host}"; }
          { text = "{dir}"; }
          { text = "{progress}"; }
        ];
      };

      profiles = {
        bash.command = bashCmd;

        framework = {
          command = "ssh framework";
          icon = ''<svg viewBox="0 0 24 30" fill="#325FFF" xmlns="http://www.w3.org/2000/svg"><path stroke="#325FFF" d="M14.8858 17.2011C17.3518 15.9572 18.9959 13.7422 18.9959 10.4707C18.9959 5.73384 15.5291 2.53051 10.3646 2.53051H0V25.2072C0 25.9048 0.585682 26.4703 1.30816 26.4703H3.53463C4.2571 26.4703 4.84278 25.9048 4.84278 25.2072V18.4279H9.04225C9.45326 18.4279 9.8464 18.4109 10.2395 18.3938L13.8176 25.7445C14.0333 26.1875 14.4946 26.4703 15.0015 26.4703H17.5317C18.5019 26.4703 19.1345 25.4862 18.704 24.6467L14.8858 17.2011ZM4.84278 6.77322H9.95362C12.3125 6.77322 14.0816 8.15338 14.0816 10.4877C14.0816 12.7369 12.4197 14.2874 9.93575 14.2874H4.84278V6.77322Z"/></svg>'';
          tab-color = "#325FFF";
          color-style = "bottom";
        };

        mac = {
          command = "ssh mac";
          icon = "🍎";
          tab-color = "#bb2124";
          color-style = "bottom";
        };

        mbp = {
          command = "ssh mbp";
          icon = "💻";
          tab-color = "#bb2124";
          color-style = "bottom";
        };

        home-server = {
          jetmux = {
            host = "home-server";
            session = "test";
          };
          icon = "🖥️";
          tab-color = "#613d7c";
          color-style = "bottom";
        };

        digdugdev = {
          command = "ssh digdugdev";
          icon = "🌐";
          tab-color = "#f0ad4e";
          color-style = "bottom";
        };

        magicschool = {
          command = "ssh magic";
          icon = "🪄";
          tab-color = "#613d7c";
          color-style = "bottom";
        };

        beast = {
          command = "ssh bduggan@100.82.226.111";
          icon = "🐺";
          tab-color = "#fab005";
          color-style = "bottom";
        };

        lakehouse = {
          command = "ssh bduggan@bduggan-desktop";
          icon = "❄️";
          tab-color = "#925FFF";
          color-style = "bottom";
        };
      };

      keybinds = {
        "ctrl+shift+h" = "new_tab:home-server";
        "ctrl+shift+d" = "new_tab:digdugdev";
        "ctrl+shift+b" = "new_tab:beast";
        "ctrl+shift+t" = "new_tab:framework";
        "ctrl+shift+w" = "new_tab:magicschool";
        "ctrl+shift+m" = "new_tab:mac";
        "ctrl+backspace" = ''text:\x17'';
      };

      plumb.code = {
        match = ''(?<file>[\w./\\:-]+\.\w+):(?<line>\d+)'';
        on = "local";
        run = [ "code" "--goto" "{file}:{line}" ];
      };
    };
  };
}
