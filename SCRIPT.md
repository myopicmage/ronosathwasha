# Script notes

**Working notes on the letterforms, not decisions.** `LANGUAGE.md` records what
has been decided about the language. This records current thinking about the
shapes that write it, and the evidence behind it.

Nothing here is implemented. Written 2026-07-28, out of an evening of measuring
and sketching against the built font.

## The question

The consonants are up for redraw. Two complaints, both Kevin's: the base forms
are busy, and the system is inconsistent. Both turned out to be true in ways that
are measurable rather than aesthetic.

## What is not up for redraw

- **The vowel chevrons.** Height and backness collapse into one geometric
  property, direction, so one construction rotated twelve ways carries two
  features for the price of a single stroke. That is the cleverest thing in the
  script and it is cheap. It stays.
- **The em square.** Consonant in the middle, vowel attached at the same anchor,
  one square per syllable, no ascenders or descenders. This is the CJK and
  Hangul arrangement, and it is why the density argument below applies at all.
- **The pipeline.** Centrelines stroked with one nib. It is the nearest thing
  the script has to a hand, and it is consistent across every glyph.

## Constraints for anything new

**1. The periphery belongs to the vowel.** A chevron's vertex sits at
`CHEVRON_REACH` 44 from centre and its arms run 22 further, so vowel ink reaches
roughly 6 and 94 in the specimen box. Consonants occupy about 24 to 76. There is
no third band, which is the whole reason constraint 3 exists.

**2. Vary density, and make it mean something.** Chinese and Japanese are read
at small sizes despite high stroke counts, because a 3-stroke character and a
15-stroke one have visibly different grey values and grey survives blur. This
script has the opposite property: every glyph is one to four thin strokes at an
identical nib, so at small sizes they become twelve identical smudges.

Current density tracks nothing. `c_s` is a three-stroke tally, `c_sh` four,
`c_t` two long crossing strokes, `c_m` a single bar. If weight is going to vary
it should carry a feature. The phonology nominates one: the stop series is
exactly /t d/ with no labial or velar stop anywhere, which is the marked
category, and those two are already the heaviest.

**3. Features by modification, not addition.** This is spatial, not taste.
Constraint 1 leaves no free space for an added mark, and the evidence is
concrete:

- `HOOK` opens with its own vertical at `M62,24 L62,56`. `STEM` is at
  `M50,25 L50,75`. Two parallel verticals twelve units apart under a 4.6 nib.
- `c_y` is `M26,72 L50,72 L50,28 L74,28`, so its vertical is at x=50 from 28 to
  72. `STEM` is at x=50 from 25 to 75. **A stem on `y` is invisible.** It lands
  on a stroke the letter already has and extends it by three units at each end.

So marking voicing by adding a stem to all seven voiced consonants fails on two
of the seven, and it fails for want of room rather than for want of care.

**4. Place by slant.** Tested against the crossbar and better on both counts.
`l` against `r` and `s` against `sh` are separable at 23px when the post-alveolar
member is the same shape tipped back, and not separable when it wears a
crossbar. It also costs one stroke fewer, and "further back in the mouth" is
something a slant can actually mean.

**5. Whatever replaces `c_t` must be sparse enough to host a contrast.** Two
chevrons driven into each other until the arms cross twice is a dense mesh, and
nothing survives inside it: an added stem is absorbed, a break closes up. `t` and
`d` are the same dark blob at 23px under every scheme tried. The mark is not the
problem, the host is.

## Why the current derivation reads as inconsistent

`STEM` marks voicing on `t`/`d` and `th`/`dh`. `CROSSBAR` marks place on `s`/`sh`
and `l`/`r`. Each mark fires exactly twice, over four derived glyphs out of
eleven.

Voicing is a real binary across the whole inventory (`m n d dh l r y` against
`t th s sh`), but only two pairs show it. **A featural mark that appears twice
never repeats often enough to be learned as a rule**, so it reads as two ad hoc
derivations wearing a system's clothes.

`CROSSBAR` has a second problem. It is near-horizontal, which is exactly `c_m`'s
silhouette, so anything wearing it acquires an m-ish element. And because it
crosses its host, `path.simplify()` fuses the two: `c_sh` is a single contour of
90 points. It never reads as a mark *on* a letter, it just becomes more letter.

## Known cost that is being accepted

**The vowel mirror pairs.** `i`/`u` and `e`/`o` are pure reflections, which is
four of six. Mirror discrimination is close to the weakest thing human vision
does, and it is why `b` and `d` take children so long. This is the direct price
of backness-as-direction, and backness-as-direction is the part worth keeping.

Latin ships four mirror-confusable letters and readers cope. The cost is
learning time, not illegibility.

## Tried and rejected

Recorded so they are not retried.

| tried | outcome |
|---|---|
| unequal chevron arms, keyed to rotation | invisible at 34px; the `m` bar lies along one arm and absorbs it |
| chevron angle keyed to backness, 45 vs 63 degrees | worked, and rejected: it changes the chevrons |
| vowel anchor shifted by backness, plus or minus 70 | stable and too weak to matter; stability and cue strength are the same dial |
| a systematic "aperture" set | all four fricatives collapsed into pairs of parallel lines |
| a "sonority ladder" set, strokes by manner | `t` and `d` became near-identical, and it came out heavier than the current 23 strokes |

The last two failed the same way: they bought systematic construction by
spending pairwise distinctness. With eleven consonants and four of them
fricatives there is a floor on how systematic the set can get before family
members stop being tellable apart. **The variety in the current consonants is
doing real work**, which is worth remembering while replacing them.

## Measurements

From `build/Ronesathwasha.ttf`, advance 1000.

| | units |
|---|---|
| ink across all 132 syllables | 37 to 963 |
| widest syllable, `mwe` | 866 |
| narrowest syllable, `la` | 388 |
| median syllable | 704 |
| current consonant strokes, all eleven | 23 |

The spread matters more than the slack. Uniform tightening is nearly pointless,
because the widest syllable already fills the square: the floor before glyphs
touch is 926, so about 5% is available. Proportional advances take a ten-syllable
line from 10.52 em to 7.47 em, because the narrow syllables are the ones
swimming.

That is a separate decision from the letterforms, and it is downstream of them:
proportional advances are computed from ink boxes, so any redraw rebuilds them.

## Open

- **Is there a single geometric property that place, manner and voicing collapse
  into**, the way direction collapses height and backness? If there is, the
  consonants get cheap. If there is not, they want to be drawn as eleven
  distinct forms with the features as rationale rather than as construction.
- **Does the hook survive?** It is the only consonant that belongs to no
  derivation family, and its own comment in `sources/strokes.py` defines it
  purely by what it must avoid.
- **In-universe**, the script began as magical notation. Reading like a diagram
  rather than like handwriting is the goal, not a fault. The `Magical
  Connections` note in the Scrivener project says magic is personal and hard to
  teach, so a notation for it would not be systematic; the Ancient World was a
  voluntary federation that unified disparate cultures under a shared language,
  which is a mechanism for a standardisation with irregular survivals in it.
