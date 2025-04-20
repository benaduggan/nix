{ pkgs, pog }:
let
  importPog = file: import file { inherit pkgs pog; };
in
{
  spelltree = importPog ./spelltree.nix;
}
