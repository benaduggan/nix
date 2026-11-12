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
    # ggml's CPU instruction set: strata_ggml.cmake FORCE-sets GGML_NATIVE and every
    # GGML_AVX*/GGML_AVX512* itself, so -DGGML_* from here is ignored. STRATA_PORTABLE is
    # the switch that actually matters - it pins the AVX2 baseline (AVX2/FMA/F16C/BMI2)
    # instead of -march=native, so the binary is not tied to whichever CPU did the build.
    # beast (Ryzen 9 5950X, Zen 3) has AVX2 but no AVX-512, and the experts' CPU dots are
    # the only part this affects; the layers themselves run on the GPU (sm_${cudaArch}).
    "-DSTRATA_PORTABLE=ON"
  ];

  env = {
    CUDAToolkit_ROOT = cudaPackages.cudatoolkit;
    CUDAToolkit_INCLUDE_ROOT = cudaPackages.cudatoolkit;
    CUDAToolkit_LIBRARY_ROOT = cudaPackages.cudatoolkit;
  };

  buildFlags = [ "--target" "strata" "--target" "strata-device" ];

  # The BUILD.json heredoc below sits at a shallower indent than the rest of the script on
  # purpose: nix strips an ''-string by its least-indented line and bash wants the closing
  # EOF at column 0 of the script that results, so do not re-indent it. Keep comments about
  # it outside the string as well - any change to this script text rebuilds the CUDA engine.
  # (BUILD.json is Strata's own build record; its control code reads it to decide what the
  # binary was compiled for: strata_control/engine_component.py, vision_reader.py.)
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
        cat > $out/bin/BUILD.json <<EOF
    {
      "version": "${version}",
      "archs": [${cudaArch}],
      "ptx": false,
      "source": "nix",
      "vision": "none"
    }
    EOF
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
