{ lib
, cmake
, ninja
, autoAddDriverRunpath
, cudaPackages
, src
, llamaSrc
, version
, cudaArch
}:

cudaPackages.backendStdenv.mkDerivation {
  pname = "strata-engine";
  inherit version;
  inherit src;
  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs = [ cudaPackages.cudatoolkit ];

  cmakeFlags = [
    "-DCMAKE_GENERATOR=Ninja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    "-DCMAKE_CUDA_ARCHITECTURES=${cudaArch}"
    "-DCMAKE_CUDA_COMPILER=${cudaPackages.cuda_nvcc}/bin/nvcc"
    "-DSTRATA_GGML_DIR=${llamaSrc}"
    # STRATA_PORTABLE=ON pins AVX2 baseline instead of -march=native; strata_ggml.cmake overrides -DGGML_*.
    "-DSTRATA_PORTABLE=ON"
  ];

  env = {
    CUDAToolkit_ROOT = cudaPackages.cudatoolkit;
    CUDAToolkit_INCLUDE_ROOT = cudaPackages.cudatoolkit;
    CUDAToolkit_LIBRARY_ROOT = cudaPackages.cudatoolkit;
  };

  buildFlags = [ "--target" "strata" "--target" "strata-device" ];

  # BUILD.json is read by strata_control to detect compiled archs/features.
  installPhase = ''
    runHook preInstall
    bin=$(find "$NIX_BUILD_TOP" -maxdepth 4 -type f -name strata | head -1)
    dev=$(find "$NIX_BUILD_TOP" -maxdepth 4 -type f -name strata-device | head -1)
    if [[ -z "$bin" ]]; then
      echo "strata binary not found under $NIX_BUILD_TOP" >&2
      exit 1
    fi
    install -Dm755 "$bin" $out/bin/strata
    [[ -n "$dev" ]] && install -Dm755 "$dev" $out/bin/strata-device
    install -Dm644 ${builtins.toFile "BUILD.json" (builtins.toJSON {
      inherit version;
      archs = [ (lib.toInt cudaArch) ];
      ptx = false;
      source = "nix";
      vision = "none";
    })} $out/bin/BUILD.json
    runHook postInstall
  '';

  meta = {
    description = "Strata inference engine for Qwen3.8-Flash-Next (125B MoE) on a single NVIDIA GPU (sm_${cudaArch})";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata";
  };
}
