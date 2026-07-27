# Language notes

**Current decisions about ronosathwasha itself.** The original December 2023
Scrivener material is preserved in `notes/scrivener-language-notes.md`, and its
example sentences are transcribed in `data/examples.toml`. Those files are
historical evidence; later decisions recorded here take precedence.

Decisions 1 and 6 are implemented in the data files. The rest are decided in
principle and not written into `data/script.toml`, because they are lexicon and
grammar, and nothing in the font depends on them.

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

**Owed: the closed class needs respelling.** The canonical backlog is
`[respell]` in `data/lexicon.toml`, which currently holds seventeen entries and
is the authority. It is deliberately not copied here, because a second copy is a
second thing to get wrong.

Two separate decisions feed that one table: the affricates above, and the `h`
and `w` question still under Open. The entries that hurt are the structural
ones rather than the vocabulary, because grammar cannot be exercised without
them: `je` (past), `ji` (continuous), `hi` (towards), and the
`chi`/`cha`/`chu` demonstratives.

The subject particle is no longer a design question. Decision 7 replaces
historical `ju` with `-ri/-ru`; moving that decision into the lexicon and
generated examples is still owed.

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

## 4. `ya` withdraws from the conversation

`ya` remains the third-person singular pronoun for something not alive. A
speaker may also use it self-referentially, deliberately replacing first-person
`la` with the nonliving `ya`.

Used alone, `ya` means that the speaker declines to present themself as an
animate participant. Context supplies the immediate reading:

- when exhausted: "I am too tired for this";
- after a request: "I do not want to";
- during an argument or incoming lecture: "I know, enough, stop";
- when presented with a consequence: "I do not care" or "not my concern."

These are not separate dictionary meanings. They are pragmatic consequences of
one stance: **the speaker is unavailable as an agent**. Functionally, it
occupies some of the same conversational territory as English *meh* and Spanish
*ya*, but reaches it through the language's existing pronoun system.

Applying `ya` to another living person instead denies that person's agency and
is pointedly rude. The self-directed use is conventional and usually comic,
weary or dismissive rather than self-abusive.

This decision does not establish a productive animacy marker for first- or
second-person pronouns, nor does it settle whether animacy can be reassigned to
ordinary nouns. Those remain open.

## 5. The lexicon predates harmony

**Harmony was decided after the language was already underway, so the existing
lexicon is stale rather than authoritative about it.** A disharmonic entry is an
entry awaiting repair, not evidence about how harmony works.

This matters because a stale entry is perfectly writable. Nothing in the font or
the keyboard objects to `thino`, so it presents as current unless something says
otherwise. Three states, not two:

| state | writable | consistent with current decisions |
|---|---|---|
| canonical | yes | yes |
| `[respell]` backlog | no | blocked on decision 1 and on `h`/`w` |
| harmony-stale | **yes** | no |

**The affixes look better than the roots.** Testing the 2023 corpus against the
alternating set, taking the stem's first vowel as governor: `mirime`, `thinome`
and `twame` all take the correct alternant, and only `rone` fails. The pronoun
plurals are more striking still, marking `la`/`lo`, `na`/`no`, `ða`/`ðo` and
`ya`/`yo` with a back vowel throughout.

So the repair may fall mostly on roots, and the affix system may have been doing
harmony intuitively before it was written down. One counterexample in four is
not enough to call it.

**Two corrections to the 2023 record**, which the transcription preserves
faithfully and should keep preserving:

- **Subject and object are separate particles**, not one particle with two
  uses. Historical `ju` marks the subject and `yi` marks the object. Decision 7
  replaces only the subject particle.
- **`Ðayi runeyi time` glosses `-yi` as a subject marker**, which is a mistake
  in the source rather than an animacy rule. The current subject form begins
  `ðari`, not `ðayi`.

## 6. The autonym is repaired

**`ronosathwasha`.** **Implemented**, in `data/script.toml` and
`data/lexicon.toml`, in the commit for `32ea4c4`.

The name is `rono` + `sa` + `thwasha`, "people's language", and `rono` is `ro`
(back) plus the plural marker. The alternating set gives `-no` after a back
stem, so the name repaired itself by derivation rather than being rechosen.
Still five legal CV syllables, so it remains usable as the smoke test.

**The disharmony came from an affix, not a root**, which is why this could be
settled while the question under Open is still parked. `-ne/-no` alternates
either way.

`rone` ("people") became `rono` in the same change, as the first entry of the
repair pass that decision 5 implies.

**Still owed**: the font family name and the keyboard layout name are hardcoded
in `tools/build_ufo.py` and `tools/build_keylayout.py` rather than read from
`data/script.toml`, and the Python package, the UFO directory and the docs all
still say `ronesathwasha`.

## 7. The subject particle is `-ri/-ru`

Historical `-ju` is replaced by a harmonic pair: **`-ri` after front stems and
`-ru` after back stems**. A stem containing only neutral vowels takes the front
form. This gives the singular pronouns `lari`, `nari`, `ðari` and `yari`; the
back-vowel plurals become `loru`, `noru`, `ðoru` and `yoru`.

The choice does four jobs at once:

- `r` is an approximant, preserving the fluid sound of the language;
- the alternating vowel keeps the visible lean of a harmonic word;
- it contrasts with object `-yi/-yu` and possessive `-sa`;
- `-ru` closes into a recognizable loop in the formal script.

That loop gives back-harmonic subjects a repeated visual ending without adding
punctuation or another feature to the writing system.

## 8. The formal script resists handwriting

**The script was designed for exact reproduction by the magical book network,
not for rapid handwriting.** Its geometric vowels, visible harmony and
carefully derived consonants make phonology inspectable, but they make a page
slow and awkward to produce with a pen.

That tradeoff fit the civilization that standardized it. A central council
could update the books directly, so faithful magical reproduction mattered more
than scribal convenience.

When the network failed, the script outlived the infrastructure it assumed.
Hand-copying became necessary precisely when authoritative copies stopped
appearing. Local shortcuts, degraded forms and incompatible cursive traditions
therefore became another pressure toward the language's later fragmentation.

## Open

- **Whether harmony is a constraint or a rule.** Decision 2 states it as a
  property of every word: "a word's vowels agree on backness." The alternating
  affix table implies instead that it governs affix selection, which is what
  Finnish and Turkish actually do, and it is the only reading the current
  lexicon satisfies. The two differ in how much of decision 5's repair pass
  falls on roots.
- **What else may flip the lean.** If a change of lean means negation, it must
  not also mean a compound boundary, or the signal is ambiguous. Recommendation:
  give the flip one job, and let harmony span compounds. **Parked**: this needs
  discussion and language work, and it sits downstream of the question above.
- **Vowel length.** Untaken, and the largest remaining fluidity lever. Both
  Finnish and Japanese are heavily length-contrastive and neither is doing that
  work here. It would sit on the vowel marks, not the consonants.
- **`h` and `yəwə`.** Still unwritable, from the earlier decision to respell
  rather than add /h/ back. `hiðə` (right) and `hwiðə` (east) need new
  consonants; any of `t d th dh sh y` is free of collisions for the direction
  series, though `t` and `d` are a minimal pair and the other three directions
  are maximally distinct.
