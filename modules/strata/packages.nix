# Builds Strata against beast's nixpkgs (matching host CUDA/driver) and GPU arch.
{ pkgs
, src
, llamaSrc
}:
let
  inherit (pkgs) lib;
  cudaArch = "86"; # beast's RTX 3090

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

  # Fail at eval if llama-pinned diverges from Strata's pinned ggml rev (silent miscompilation otherwise).
  pinChecked =
    if (llamaSrc.rev or "") == ggmlPin then true
    else
      throw ''
        Strata's source pins llama.cpp/ggml at ${ggmlPin}, but the llama-pinned input is locked at
        ${llamaSrc.rev or "an unknown revision"}.
        Fix: set inputs.llama-pinned.url = "github:ggml-org/llama.cpp/${ggmlPin}" in flake.nix,
        then run: nix flake lock --update-input llama-pinned'';
  engine = pkgs.callPackage ./engine.nix {
    inherit version cudaArch src llamaSrc;
  };
in
assert pinChecked;
{
  strata = pkgs.callPackage ./serve.nix {
    inherit version engine llamaSrc;
    strataSrc = src;
  };
}
