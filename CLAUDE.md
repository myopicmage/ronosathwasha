# conlang

A font and input method for a constructed script: a strict consonant+vowel syllabary,
encoded in the Unicode Private Use Area.

## Learning mode is scoped

The `learning-mode` skill defines the working loop (plan first, one stop at a time,
explanation arrives with the edit, one commit per stop, advance on a go-word).

Use it automatically for two parts of this project:

- **The font and input stack.** The learning axis is text technology, not Python.
  Concretely, the things worth stopping to explain:

  - **Unicode encoding model.** Why real scripts got the encoding they did, what
    precomposed vs decomposed costs, normalization, and where the PUA leaves us on our
    own.
  - **OpenType shaping.** GSUB and GPOS as the two halves of the shaping engine, the
    feature file (`.fea`) language, anchors and mark attachment, and how a shaper decides
    what runs.
  - **Shaping engines in practice.** Where CoreText, HarfBuzz and DirectWrite disagree,
    and why an unencoded script cannot lean on script-specific shaper logic.
  - **The macOS input stack.** `.keylayout` XML, dead-key state machines, and the line
    where a keyboard layout stops being enough and an InputMethodKit IME starts.
- **The language-development chatbot.** The learning axes are Raku and the mechanics of
  local LLM integration: inference, prompts, context-window management, and the boundary
  between conversational state and durable language knowledge.

Do not invoke learning mode automatically for language design, vocabulary, prose,
HTML, ordinary Python or XML, or build wiring. Kevin can still opt any task into it
explicitly. In font work, do call out gnarly library idioms in `fontTools` / `fontmake`
where they are genuinely non-obvious.

**A stop here is one file, not one logical unit.** The skill's default unit is
calibrated to repositories where Kevin can already see the shape of a change: many
near-identical edits across files, or a familiar pattern repeating. Raku and text
technology are both unfamiliar territory, so a stop that spans several files hides
exactly the structure he is trying to learn.

So: one production file per gate, plus whatever test proves it. The test is
verification rather than a second lesson, and shipping an unverified module to
respect a file count would be the wrong trade. Where a single file is large enough
that it is really several ideas, say so before starting and split it.

Revisit this once Kevin says he has the lay of the land. It is a scaffold for
unfamiliarity, not a permanent property of the repository. Plans written elsewhere,
including the shared-work plan for the chatbot, use much coarser stops; treat those
as the work breakdown and this as the gate size.

**Define font vocabulary the first time it appears.** Kevin is fluent in the languages
and new to type. Any term of art from typography, font engineering or OpenType gets a
short gloss inline the first time it comes up in a turn, and an entry in `GLOSSARY.md`.
This covers the domain, not programming: parser, enum and dataclass need no gloss;
advance width, mark class, GSUB and shaping all do. When in doubt, gloss it. A term used
without explanation is the one thing that reliably makes this work opaque.

## Stack

- Python, with `fontTools` + `fontmake`, sources in UFO. This is the Google Fonts pipeline
  and the de facto standard for open font development.
- Raku, for the chatbot. `META6.json` declares the distribution, `lib/Ronosathwasha/`
  holds the modules and `t/*.rakutest` the tests. Run them with `make raku-test`, which
  `make check` includes.
- A nix flake provides the dev shell. Enter it with `nix develop 'path:.'`.

**nixpkgs packages no Raku modules at all**, so every ecosystem dependency comes from
`zef` rather than from the flake. `META6.json` is the declaration and `.raku/` is the
installed copy, untracked and rebuilt by `make`. Raku names a module repository by a
spec rather than a path, so the two halves are `zef install --to="inst#.raku"` and
`RAKULIB="inst#.raku"`. zef cannot install into rakudo's own repository because it lives
in the read-only nix store.

Two traps, both already worked around in the `Makefile` and both invisible until they
bite:

- **`zef install --deps-only` exits nonzero when every dependency is already
  installed**, reporting the skips as install failures. No recipe may gate on its
  status; the target checks for the repository directory instead, and `make raku-test`
  is the real verification.
- **`#` opens a comment in a `Makefile` even inside quotes**, so a repository spec has
  to be escaped. It behaves differently in the two places it can appear: `\#` in a
  variable assignment yields a literal `#`, while `\#` written directly in a recipe
  passes the backslash through to the shell and zef then reads `inst\` as an unknown
  repository type. Build the spec once in a variable and use that variable everywhere.

**Two Raku language traps that keep recurring.** Both are silent, both produce
plausible data rather than an error, and both are already documented inside
individual modules where they only help whoever opens that module. They are here
because that is not enough: each has bitten more than once.

- **`*@args` is the flattening slurpy and `**@args` is not.** A single star
  flattens its arguments, so `f((a, b), (c, d))` arrives as four items rather than
  two pairs, and every field of every element then reads as undefined. Reach for
  `**@` whenever the arguments are lists, pairs or hashes. Documented already in
  `TestModel.rakumod`'s `scripted`, and hit again in `t/18` regardless.
- **An enum's values become symbols in every importing scope, so they collide with
  classes.** A class named `Invariant` alongside `Types`' `Alternation` value of
  that name does not shadow it or lose to it: any module importing both fails to
  compile, and the error names the second `use` rather than the enum it clashed
  with. Four occurrences so far. `VowelProfile` is suffixed for it, `FindingKind` is
  flattened rather than nested for it, the exceptions are rooted under
  `X::Ronosathwasha` for it, and `PromptInvariant` is prefixed for it. **Check
  `Types.rakumod`'s enums before naming a new exported class**, and expect the
  collision, because those values are ordinary words: `Current`, `Writable`,
  `Prefix`, `Suffix`, `Front`, `Back`, `Harmonic` and `Invariant` are all taken.
  `MorphemeRole` uses `Marks-` prefixes for the same reason, since a value named
  `Tense` would collide with the type of that name in `Semantics`.

**The flake uses `mkShellNoCC`, and must keep doing so.** `mkShell` pulls in nix's C
compiler wrapper, which sets `SDKROOT` and `DEVELOPER_DIR` to a nixpkgs `apple-sdk`. On
this machine that SDK was built by Swift 5.10 while `/usr/bin/swift` is 6.3.3, and the
compiler refuses an SDK that does not match its own version, so `swift` will not run at
all inside the shell. Nothing here compiles C, so the wrapper costs nothing to drop.

Symptom if it comes back: `failed to build module 'Swift'; this SDK is not supported by
the compiler`. The same trap is documented in the BRBAviation `nix-dev-env` skill, which
solves it with `mkShellNoCC` plus a `shellHook`; the hook is not needed here.
