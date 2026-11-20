{ lib
, writeShellApplication
, curl
, jq
, nix
}:
{ pname
, owner
, repo
, dataFile
, assets
}:
lib.getExe (writeShellApplication {
  name = "update-${pname}";
  runtimeInputs = [ curl jq nix ];
  text = ''
    auth=()
    [[ -n "''${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

    release="$(curl -fsSL -H "Accept: application/vnd.github+json" "''${auth[@]}" \
      ${lib.escapeShellArg "https://api.github.com/repos/${owner}/${repo}/releases/latest"})"
    version="$(jq -er '.tag_name | ltrimstr("v")' <<< "$release")"

    json="$(jq -cn --arg version "$version" '{ version: $version, artifacts: {} }')"
    while IFS=$'\t' read -r system name digest; do
      sha256="$(nix hash convert --hash-algo sha256 --to sri "$digest")"
      json="$(jq -cn \
        --argjson cur "$json" \
        --arg sys "$system" \
        --arg name "$name" \
        --arg sha256 "$sha256" \
        '$cur | .artifacts[$sys] = { name: $name, sha256: $sha256 }')"
    done < <(jq -er --arg version "$version" --argjson assets ${lib.escapeShellArg (builtins.toJSON assets)} '
      . as $rel | $assets | to_entries[] |
      (.value | gsub("\\{version\\}"; $version)) as $name |
      ($rel.assets[] | select(.name == $name)) as $a |
      [.key, $name, ($a.digest // error("missing digest for " + $name))] | @tsv
    ' <<< "$release")

    printf '%s\n' "$json" | jq --sort-keys '.' > ${lib.escapeShellArg dataFile}
    echo "${pname}: $version"
  '';
})
