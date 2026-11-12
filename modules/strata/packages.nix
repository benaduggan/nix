# Builds the Strata packages (Qwen3.8-Flash-Next local inference) for beast: against
# beast's nixpkgs, so the engine's cudart matches the host's driver, and for its GPU.
#
#   import ./modules/strata/packages.nix {
#     pkgs = beastPkgs;        # nixos-unstable, allowUnfree
#     src = inputs.strata;     # github:Niko1221/Strata
#     llamaSrc = inputs.llama-pinned;  # ggml-org/llama.cpp at Strata's pin
#   }
{ pkgs
, src
, llamaSrc
}:
let
  inherit (pkgs) lib;

  # beast's RTX 3090. Another GPU would mean another call here, not an option: the
  # engine's kernels are compiled for one arch ("89" RTX 40, "120" RTX 50).
  cudaArch = "86";

  version =
    let
      projectLine = builtins.head (builtins.filter
        (l: builtins.match "project\\(strata VERSION.*" l != null)
        (lib.splitString "\n"
          (builtins.readFile (src + "/CMakeLists.txt"))));
    in
    builtins.head (builtins.match "project\\(strata VERSION ([0-9.]+).*" projectLine);

  ggmlPin = builtins.head (builtins.match "([0-9a-f]+).*"
    (builtins.readFile (src + "/third_party/ggml/VERSION.txt")));

  # The one place the llama.cpp pin is checked: ggml is the engine's tensor library, so
  # building it from a different revision than Strata pins is not a supported build - it
  # would compile and produce wrong output rather than fail. Fail at eval instead; the
  # assert below forces that check even when only strata-serve is asked for.
  pinChecked =
    if (llamaSrc.rev or "") == ggmlPin then true
    else
      throw ''
        Strata's source pins llama.cpp/ggml at ${ggmlPin}, but the llama-pinned input is locked at
        ${llamaSrc.rev or "an unknown revision"}.
        Fix: set inputs.llama-pinned.url = "github:ggml-org/llama.cpp/${ggmlPin}" in flake.nix,
        then run: nix flake lock --update-input llama-pinned'';
  # CUDA inference binary, built from the pinned Strata source.
  engine = pkgs.callPackage ./engine.nix {
    inherit version cudaArch;
    inherit src llamaSrc;
  };
in
assert pinChecked;
# The one thing callers use: the bundle the service runs (bin/strata-serve,
# bin/strata-chat, bin/strata-prefetch), with the engine under passthru.engine.
{
  strata = pkgs.callPackage ./serve.nix {
    inherit version engine;
    strataSrc = src;
    inherit llamaSrc;
  };
}
