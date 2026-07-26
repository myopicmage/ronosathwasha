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

## Stack

- Python, with `fontTools` + `fontmake`, sources in UFO. This is the Google Fonts pipeline
  and the de facto standard for open font development.
- A nix flake provides the dev shell. Enter it with `nix develop 'path:.'`.
