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
        # mkShellNoCC, not mkShell. mkShell pulls in nix's C compiler wrapper,
        # which sets SDKROOT and DEVELOPER_DIR to a nixpkgs apple-sdk. On this
        # machine that SDK was built by Swift 5.10 while /usr/bin/swift is
        # 6.3.3, and the compiler refuses an SDK that does not match itself, so
        # `swift` will not run at all inside the shell. Nothing here compiles C,
        # so dropping the wrapper costs nothing and those variables are simply
        # never set.
        default = pkgs.mkShellNoCC {
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
