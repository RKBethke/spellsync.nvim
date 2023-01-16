{
  description = "Flake for tweaking neovim configuration";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.bashInteractive
          ];
          buildInputs = with pkgs; [
            sumneko-lua-language-server
            stylua
            nil
          ];
        };
      });
}
