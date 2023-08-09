{ lib, pkgs, config, modulesPath, common, inputs, ... }:
with lib;
let
  hostname = "wsl";
  cuda = pkgs.cudaPackages.cudatoolkit;
  cudaTarget = "cuda114";
  WSL_MAGIC = "/usr/lib/wsl/lib";
  CUDA_PATH = cuda.outPath;
  CUDA_LDPATH = "${
      lib.concatStringsSep ":" [
        WSL_MAGIC
        "/run/opengl-drivers/lib"
        "/run/opengl-drivers-32/lib"
        "${cuda}/lib"
        "${pkgs.cudaPackages.cudnn}/lib"
      ]
    }:${
      lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib cuda.lib ]
    }";
in
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    inputs.nixos-wsl.nixosModules.wsl
    # ./cachix.nix
  ];

  nix = {
    extraOptions = ''
      max-jobs = auto
      narinfo-cache-negative-ttl = 10
      extra-experimental-features = nix-command flakes
      extra-substituters = https://jacobi.cachix.org
      extra-trusted-public-keys = jacobi.cachix.org-1:JJghCz+ZD2hc9BHO94myjCzf4wS3DeBLKHOz3jCukMU=
    '';
  };


  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = "bduggan";
    startMenuLaunchers = true;
  };


  boot.tmp.useTmpfs = true;
  environment.noXlibs = false;
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    nvidia-docker
    (pkgs.writeShellScriptBin "_invokeai" ''
      nix run github:nixified-ai/flake#invokeai-nvidia -- --web --host 0.0.0.0
    '')
    (pkgs.writeShellScriptBin "_koboldai" ''
      nix run github:nixified-ai/flake#koboldai-nvidia -- --host
    '')
  ];

  environment.variables = with pkgs; {
    NIX_HOST = hostname;
    NIXOS_CONFIG = "/home/bduggan/cfg/machines/${hostname}/configuration.nix";
    _CUDA_PATH = CUDA_PATH;
    _CUDA_LDPATH = CUDA_LDPATH;
    XLA_FLAGS = "--xla_gpu_cuda_data_dir=${CUDA_PATH}";
    XLA_TARGET = cudaTarget;
    EXLA_TARGET = cudaTarget;
  };

  networking.hostName = hostname;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  programs.command-not-found.enable = false;

  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };

  users.users.bduggan = {
    isNormalUser = true;
    description = "bduggan";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes256-ctr"
        ];
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
        X11Forwarding = true;
      };
    };
    tailscale.enable = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  systemd.services.docker.serviceConfig.EnvironmentFile = "/etc/default/docker";
  systemd.services.docker.environment.CUDA_PATH = CUDA_PATH;
  systemd.services.docker.environment.LD_LIBRARY_PATH = CUDA_LDPATH;
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;

  system.stateVersion = "22.05";
}
