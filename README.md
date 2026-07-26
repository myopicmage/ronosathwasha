# ronesathwasha

A font and a macOS keyboard layout for a constructed script: a strict
consonant-plus-vowel syllabary, encoded in the Unicode Private Use Area.

`ronesathwasha` is `rone` + `sa` + `thwasha`, "people's tongue".

11 consonants x 12 vowels = 132 syllables. Every syllable is exactly one
consonant and one vowel: no onsetless syllables, no codas, no clusters.

## Using it

```sh
nix develop 'path:.'              # or just cd in, direnv handles it
python3 -m tools.build_font       # declaration -> UFO -> build/Ronesathwasha.ttf
python3 -m tools.build_dictionary # lexicon -> build/dictionary.html
python3 -m pytest                 # 63 tests
python3 -m mypy                   # strict
```

Install both halves:

```sh
./scripts/install.sh
```

Builds and installs together, on purpose: a font one encoding behind a keyboard
renders as fluent nonsense rather than as an error. It enters the dev shell
itself if it needs to.

## The dictionary

```sh
python3 -m tools.build_dictionary
open build/dictionary.html
```

Every word in `data/lexicon.toml`, searchable by English gloss or by
romanisation, each one shown in the script.

**The font is inlined into the page**, so it renders on a machine that has never
installed anything here. That is not a convenience: the script lives in the
private use area, and a PUA code point with the wrong font renders either as
tofu or, if some other font claims the same block, as somebody else's letters.
The page has to carry its own decoder.

The font is compiled during the build rather than read from `build/`, for the
same reason `install.sh` builds both halves together.

Searching matches the gloss and the romanisation, never the encoded text. The
PUA gets nothing from Unicode's casefolding or collation, so a search over it
could only ever be an exact substring match, on characters with no keys.

Fonts refresh immediately. **The keyboard layout needs a log out and back in**,
because macOS only scans that directory at login, and the script says so only
when the layout actually changed. Then enable it under System Settings >
Keyboard > Input Sources, at the bottom of the list under **Others**.

## Typing

Consonants are dead keys: they emit nothing and arm a state. The vowel fires
and emits the whole syllable. **Every consonant sits on the letter it is
romanised with**, so you type what you would write and the layout needs no
diagram. Shift is only the glide.

`H` is not a phoneme here, which frees it to complete the digraphs: `t` followed
by `h` can only ever have meant `th`.

| key | letter |
|---|---|
| `M` | m |
| `N` | n |
| `T` | t |
| `D` | d |
| `S` | s |
| `L` | l |
| `R` | r |
| `Y` | y |
| `H` | completes a digraph: `T H` = th, `D H` = dh, `S H` = sh |
| `A` `E` `I` `O` `U` `;` | a e i o u ə, with shift for the glide |


Fifteen keys for the whole writing system. To type the language's own name:

```
R  O   N  E   S  A   T H  Shift+A   S H  A
ro     ne     sa     thwa           sha
```

Two things that look like bugs and are not:

- **A consonant key appears to do nothing.** That is a dead key working. The
  syllable appears when you press the vowel.
- **A vowel key does nothing at all.** You are in the neutral state and there is
  no consonant for it to attach to. This language has no onsetless syllables, so
  the layout has no state in which one is reachable.

## Numbers and punctuation

Latin, for now. The script has no numerals or punctuation of its own and is not
getting any: questions, negation and commands are all marked morphologically
(`tho`, `ma`, `yo`), so the grammar covers what punctuation usually would.

The font carries no glyphs for them either, so digits and stops come from
whatever font the system falls back to. That works, and the only visible cost is
that they will not match the script's weight.

## How it fits together

Everything is generated from one declaration, so nothing is stated twice.

```
data/script.toml       the inventory, the PUA block, the derivation rules
data/lexicon.toml      the words: a romanisation and a gloss, nothing derivable
ronesathwasha/         those files parsed into models that cannot hold a broken one
sources/strokes.py     the consonant letterforms, as centrelines
tools/                 the generators: UFO, font, keyboard layout, dictionary
layouts/               the generated .keylayout
scripts/install.sh     build both and put them where macOS looks
tests/                 model, shaping (HarfBuzz), shaping (CoreText), keyboard
GLOSSARY.md            font and typography terms, in the order you meet them
```

Deliberately absent from `data/script.toml`, because both are derivable and a
second copy is a second thing that can disagree:

- **The six glide vowels.** A glide is its plain vowel plus a tick at a fixed
  code point offset, so it is computed.
- **Every vowel's chevron direction.** It falls out of height and backness,
  because the mark is a picture of where the vowel sits in the mouth. Front is
  left, back is right, open is down, and the one vowel with no position is drawn
  as a ring instead of an arrow.

## The script

Both halves are featural: the shape of a letter encodes the phonology rather
than being arbitrary.

- **A vertical stem marks voicing.** `t`->`d`, `th`->`dh`.
- **A crossbar marks place**, alveolar moving back to post-alveolar. `s`->`sh`,
  `l`->`r`.
- **A vowel is a chevron pointing at its cell** in the vowel trapezoid, and the
  glide adds a tick at the chevron's tail, always opposite its point.

Every glyph is a single centreline stroked with one nib. Change `PEN` in
`sources/strokes.py` and the whole font re-weights.

## Notes

`sources/Ronesathwasha.ufo` and `layouts/Ronesathwasha.keylayout` are generated
and overwritten on every build. Edit `sources/strokes.py` for the letterforms
and `data/script.toml` for the inventory.

**`pytest` fails if either has been hand-edited or has drifted from its
generator**, so this is checked rather than remembered. The UFO also carries the
warning in `info.note`, which font editors display on open.

`build/` is not tracked.
