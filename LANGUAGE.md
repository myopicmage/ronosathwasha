# Language notes

**Current decisions about ronesathwasha itself.** The original December 2023
Scrivener material is preserved in `notes/scrivener-language-notes.md`, and its
example sentences are transcribed in `data/examples.toml`. Those files are
historical evidence; later decisions recorded here take precedence.

Only the first one is implemented. The rest are decided in principle and not
written into `data/script.toml`, because they are lexicon and grammar, and
nothing in the font depends on them.

## 1. The affricates are gone

`ch` /tʃ/ and `j` /dʒ/ dropped. **Implemented**, in the font and the keyboard.
11 consonants, 132 syllables.

Two reasons, pointing the same way:

- **Fluid.** An affricate is the most abrupt segment there is, a full closure
  with a strident release. Everything remaining except `t` and `d` is a
  continuant.
- **Alien.** They were also the two most English sounds in the inventory,
  *church* and *judge*. What is left is a stop series of exactly /t d/, with no
  labial or velar stop anywhere, which almost no language does.

It also repaired the script for free, which is written up in the commit for
`df924f0`.

**Owed: the closed class needs respelling.** These are all attested and all
now unwritable:

| was | gloss |
|---|---|
| `je` | past tense marker |
| `ji` | continuous tense marker |
| `ju` | subject particle |
| `chi` | this |
| `cha` | that |
| `chu` | that over there |
| `jechiswo` | to go |

## 2. Vowel harmony, on backness

![harmonic and disharmonic words](docs/harmony.png)

**Front `i e`, back `u o`, neutral `ə a`.** A word's vowels agree on backness;
the central pair are transparent and appear in either class.

Finnish's neutral vowels are front vowels behaving as transparent for
historical reasons, and everyone has to memorise that. **Here the neutrals are
neutral because they are actually central**, with no backness to agree about.
The phonology, the geometry and the harmony rule are one fact.

**The script displays it.** Backness is already drawn as direction, so a
harmonic word leans one way the whole length, and a break in harmony is visible
as a change of lean. No natural script does this, because none of them encode
backness geometrically.

Roughly half the affixes would alternate:

```
alternating   -swo/-swe   -me/-mo   -the/-tho   -ne/-no   -yi/-yu   li-/lu-
neutral       -sa   ma-   anything whose only vowel is ə or a
```

## 3. Negation is anti-harmonic

![a negator leaning against its word](docs/negation.png)

**The negator takes the opposite class to the word it attaches to.** `mo-`
before a front word, `me-` before a back one. Always the wrong lean, so it is
visible at a glance and audible without being stressed.

The attested cousin is Turkish's invariant suffixes, `-yor` and `-ki`, which sit
in a harmonised word refusing to agree. This goes one step further: an invariant
morpheme only clashes half the time, and this clashes always.

Two arguments beyond the aesthetic:

- **Negation is the morpheme you can least afford to mishear.** Languages
  already protect it, by resisting reduction and attracting stress. This is a
  better mechanism than either.
- **The form matches the meaning.** The morpheme that contradicts is the one
  that refuses to agree.

Requires replacing `ma`, whose vowel is neutral and therefore has nothing to be
disharmonious with.

## Open

- **What else may flip the lean.** If a change of lean means negation, it must
  not also mean a compound boundary, or the signal is ambiguous. Recommendation:
  give the flip one job, and let harmony span compounds.
- **Vowel length.** Untaken, and the largest remaining fluidity lever. Both
  Finnish and Japanese are heavily length-contrastive and neither is doing that
  work here. It would sit on the vowel marks, not the consonants.
- **`h` and `yəwə`.** Still unwritable, from the earlier decision to respell
  rather than add /h/ back. `hiðə` (right) and `hwiðə` (east) need new
  consonants; any of `t d th dh sh y` is free of collisions for the direction
  series, though `t` and `d` are a minimal pair and the other three directions
  are maximally distinct.
