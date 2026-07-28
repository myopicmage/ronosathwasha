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

            # The chatbot half. Rakudo is the compiler; zef is the package
            # manager, packaged separately because Raku ships no bundled one.
            #
            # zef cannot install into rakudo's own module repository, because
            # that lives in the nix store and the store is read-only. Raku
            # addresses repositories by a spec rather than a directory, so the
            # fix is to name a writable one: `zef install --to="inst#.raku"`
            # and then `RAKULIB="inst#.raku"` to find it again. That path is
            # generated and untracked, the way `build/` is.
            pkgs.rakudo
            pkgs.zef

            # hb-shape answers the only question that matters when debugging a
            # feature file: given this codepoint sequence, which glyphs come out
            # and where do they sit. nixpkgs ships the harfbuzz command line
            # tools in the `dev` output, not the default one.
            pkgs.harfbuzz.dev

            # `make share`. Showing this script to someone means showing them a
            # page, because a screenshot loses the text and the text alone is
            # unreadable without the font, so there is no way to just paste it
            # into a message. A quick tunnel is the shortest path from build/ to
            # a URL, and it is public while it is up.
            pkgs.cloudflared
          ];
        };
      });
    };
}
