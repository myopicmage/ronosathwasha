"""The letterforms, as centrelines.

This is a pen script: every glyph is a path traced with a nib of one width, not
a filled shape. So the source is the path, and the outline is derived by
stroking it. Change PEN and the whole font re-weights.

Coordinates are the 100x100 specimen box with y pointing down, the space every
specimen sheet in this project has been drawn in. `tools/build_ufo.py` converts
once, on the way into the font.

These shapes are a reading of Kevin's handwritten chart, corrected by him over
several rounds. They are meant to be edited here.
"""

from __future__ import annotations

PEN = 4.6  # nib width, specimen units

# Shared marks. Referenced rather than redrawn, so a derived letter cannot
# drift away from the mark that derives it.
STEM = "M50,25 L50,75"                      # voicing:  t->d, th->dh
CROSSBAR = "M27,56 L72,46"                  # place:    s->sh, l->r
WAVE = "M30,70 Q34,30 48,48 Q62,66 70,30"
DIAMOND = "M24,50 L50,36.5 L76,50 L50,63.5 Z"  # place: t, and d over it
# Two, not three. `sh` is the tally plus a crossbar, so a third stroke here made
# it the heaviest letter in the script at four, and it had to hold a vowel mark
# and sometimes a glide tick on top of that. Dropped from `s` rather than from
# `sh`, which is the only way `sh` stays `s` plus its crossbar.
#
# Centred on 50 rather than on 54, where the three-stroke version sat. The
# crossbar is shared with `r` and its centre is already the midpoint between
# this and the hook, so it cannot move to suit one of them; a narrower tally off
# to one side under a wide bar reads as crooked rather than as crossed.
TALLY = ["M38,70 L47,31", "M53,70 L62,31"]
# Four fifths about its own centre, then moved onto the box's, the way `c_n` and
# `c_y` were taken to two thirds. It was the tallest letter in the script at 55.1
# and the only one that was not centred, sitting 3.3 left, so the two complaints
# were one measurement: what looked like the wrong shape was the right shape in
# the wrong place at the wrong size.
#
# Four fifths lands its half-extent on 22.5, which is `c_th`'s, so the hook stops
# being one of the four letters the vowel marks have to negotiate with and
# becomes one of the six they do not. The nib does not scale with it, so it is
# darker for its size than it was; there are no counters in a single open stroke,
# which is why this letter can afford that and `c_s` cannot.
HOOK = "M62.2,29.8 L62.2,55.4 C62.2,66.6 52.6,73.0 43.8,69.0 C36.6,65.8 35.8,57.0 41.4,52.2"

CONSONANTS: dict[str, list[str]] = {
    # A single horizontal. The most featureless glyph in the set, and the one
    # that borrows its silhouette from whichever vowel it meets.
    "c_m": ["M30,50 L70,50"],
    # Scaled to about two thirds about the centre, with `c_y`. The nib does not
    # scale with them, so both letters are darker for their size than they were
    # and `n`'s three horizontals are 12 apart rather than 18.
    "c_n": ["M36,38 L64,38", "M50,38 L50,62", "M36,62 L64,62"],
    # Two chevrons driven into each other until their vertices pass, then cut
    # off where they cross: 24,50 and 76,50 are the vertices, 50,36.5 and
    # 50,63.5 are the crossings. So this is still the vowels' own primitive,
    # doubled and closed, and nothing about it was chosen for its own sake.
    #
    # The arms were what made this the worst letter to add a vowel to. They
    # reached back out to 24 and 76 in both directions, which is precisely
    # where the vowel marks now sit, so `t` grew a third and a fourth chevron
    # every time it was written. Closed, it keeps to the middle.
    "c_t": [DIAMOND],
    # 25 to 75 against a diamond 36.5 to 63.5, so the stem overshoots by 11 at
    # each end and reads as a needle through it. A taller diamond would swallow
    # the stem, and the stem cannot move: `dh` shares it.
    "c_d": [DIAMOND, STEM],
    "c_th": [WAVE],
    "c_dh": [WAVE, STEM],
    "c_s": list(TALLY),
    "c_sh": [*TALLY, CROSSBAR],
    # Open, never closing, so it stays clear of the schwa's ring; and not a
    # chevron, so it stays clear of the vowels.
    "c_l": [HOOK],
    "c_r": [HOOK, CROSSBAR],
    # _|- : low arm left, up the stem, high arm right. It used to span 48 by 44,
    # which made it the largest letter in the script that was not the diamond,
    # and the diamond at least is flat. At 32 by 30 it leaves the room the marks
    # want without giving up the shape.
    "c_y": ["M34,65 L50,65 L50,35 L66,35"],
}
