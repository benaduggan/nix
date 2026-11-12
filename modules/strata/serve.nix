{ lib
, stdenvNoCC
, makeWrapper
, python3
, strataSrc
, llamaSrc
, engine
, version
}:

let
  py = python3.withPackages (ps: with ps; [
    numpy
    jinja2
    regex
    pyyaml
    tqdm
    requests
    pillow
    psutil
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "strata";
  inherit version;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/strata/third_party/llama.cpp
    cp -rL ${strataSrc}/. $out/share/strata/
    chmod -R u+w $out/share/strata
    rm -rf $out/share/strata/{bench,docs,ref,third_party,.gitattributes,.gitignore}
    mkdir -p $out/share/strata/third_party/llama.cpp
    cp -rL ${llamaSrc}/gguf-py $out/share/strata/third_party/llama.cpp/gguf-py
    install -Dm644 ${./prefetch.py} $out/share/strata/prefetch.py
    makeWrapper ${py}/bin/python $out/bin/strata-serve \
      --add-flags "$out/share/strata/serve/server.py"
    makeWrapper ${py}/bin/python $out/bin/strata-chat \
      --add-flags "$out/share/strata/tools/chat.py"
    makeWrapper ${py}/bin/python $out/bin/strata-prefetch \
      --add-flags "$out/share/strata/prefetch.py" \
      --set STRATA_SHARE "$out/share/strata"
    runHook postInstall
  '';

  passthru = {
    inherit engine py;
  };

  meta = {
    description = "Strata local inference server (OpenAI/Anthropic-compatible API for Qwen3.8-Flash-Next)";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata-serve";
  };
}
