# conlang

A font and input method for a constructed script: a strict consonant+vowel syllabary,
encoded in the Unicode Private Use Area.

## This is a learning project

The `learning-mode` skill defines the working loop (plan first, one stop at a time,
explanation arrives with the edit, one commit per stop, advance on a go-word).

**The learning axis here is the text stack, not Python.**

Concretely, the things worth stopping to explain:

- **Unicode encoding model.** Why real scripts got the encoding they did, what precomposed
  vs decomposed costs, normalization, and where the PUA leaves us on our own.
- **OpenType shaping.** GSUB and GPOS as the two halves of the shaping engine, the feature
  file (`.fea`) language, anchors and mark attachment, and how a shaper decides what runs.
- **Shaping engines in practice.** Where CoreText, HarfBuzz and DirectWrite disagree, and
  why an unencoded script cannot lean on script-specific shaper logic.
- **The macOS input stack.** `.keylayout` XML, dead-key state machines, and the line where
  a keyboard layout stops being enough and an InputMethodKit IME starts.

Do not narrate ordinary Python, ordinary XML, or ordinary build wiring. Do call out
gnarly library idioms in `fontTools` / `fontmake` where they are genuinely non-obvious.

**Define font vocabulary the first time it appears.** Kevin is fluent in the languages
and new to type. Any term of art from typography, font engineering or OpenType gets a
short gloss inline the first time it comes up in a turn, and an entry in `GLOSSARY.md`.
This covers the domain, not programming: parser, enum and dataclass need no gloss;
advance width, mark class, GSUB and shaping all do. When in doubt, gloss it. A term used
without explanation is the one thing that reliably makes this work opaque.

## Stack

- Python, with `fontTools` + `fontmake`, sources in UFO. This is the Google Fonts pipeline
  and the de facto standard for open font development.
- A nix flake provides the dev shell. Enter it with `nix develop 'path:.'`.

**The flake uses `mkShellNoCC`, and must keep doing so.** `mkShell` pulls in nix's C
compiler wrapper, which sets `SDKROOT` and `DEVELOPER_DIR` to a nixpkgs `apple-sdk`. On
this machine that SDK was built by Swift 5.10 while `/usr/bin/swift` is 6.3.3, and the
compiler refuses an SDK that does not match its own version, so `swift` will not run at
all inside the shell. Nothing here compiles C, so the wrapper costs nothing to drop.

Symptom if it comes back: `failed to build module 'Swift'; this SDK is not supported by
the compiler`. The same trap is documented in the BRBAviation `nix-dev-env` skill, which
solves it with `mkShellNoCC` plus a `shellHook`; the hook is not needed here.
