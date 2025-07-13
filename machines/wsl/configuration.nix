# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, ... }:
let
  # cuda = pkgs.cudaPackages.cudatoolkit;
  # CUDA_PATH = cuda.outPath;
  # CUDA_LDPATH = "${
  #     lib.concatStringsSep ":" [
  #       "/usr/lib/wsl/lib"
  #       "/run/opengl-drivers/lib"
  #       # "/run/opengl-drivers-32/lib"
  #       "${cuda}/lib"
  #       "${pkgs.cudaPackages.cudnn}/lib"
  #     ]
  #   }:${
  #     lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib cuda.lib ]
  #   }";
in
{
  nixpkgs.config.allowUnfree = true;
  wsl.enable = true;
  wsl.defaultUser = "nixos";
  users.users.nixos = {
    isNormalUser = true;
    description = "nixos user";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  programs.command-not-found.enable = false;
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };


  environment = {
    systemPackages = with pkgs; [
      # cudaPackages.cudatoolkit
      # cudaPackages.cudnn
      # nvidia-docker
    ];
    variables = {
      # _CUDA_PATH = CUDA_PATH;
      # _CUDA_LDPATH = CUDA_LDPATH;
      # XLA_FLAGS = "--xla_gpu_cuda_data_dir=${CUDA_PATH}";
    };
  };


  # services = {
  #   xserver.videoDrivers = [ "nvidia" ];
  # };

  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
    daemon.settings.cdi-spec-dirs = [ "/etc/cdi" ];
    # https://github.com/nix-community/NixOS-WSL/issues/578
    ### sudo mkdir -p /etc/cdi
    ### LD_LIBRARY_PATH=/usr/lib/wsl/lib nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  };

  hardware = {
    # graphics = {
    #   enable = true;
    #   enable32Bit = true;
    # };
    # nvidia-container-toolkit = {
    #   enable = true;
    #   mount-nvidia-executables = false;
    # };
    # nvidia = {
    #   open = false;
    #   package = config.boot.kernelPackages.nvidiaPackages.stable;
    # };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
