{
  description = "Font and input method for a constructed CV syllabary";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.python3.withPackages (ps: [
              ps.fonttools
              ps.fontmake
              ps.ufolib2
              ps.ufo2ft
              ps.defcon

              # fontTools imports brotli lazily and only to read or write woff2.
              # Without it, woff2 output fails at call time rather than import time.
              ps.brotli

              ps.mypy
              ps.pytest
            ]))

            # hb-shape answers the only question that matters when debugging a
            # feature file: given this codepoint sequence, which glyphs come out
            # and where do they sit. nixpkgs ships the harfbuzz command line
            # tools in the `dev` output, not the default one.
            pkgs.harfbuzz.dev
          ];
        };
      });
    };
}
