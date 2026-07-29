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
HOOK = "M62,24 L62,56 C62,70 50,78 39,73 C30,69 29,58 36,52"

CONSONANTS: dict[str, list[str]] = {
    # A single horizontal. The most featureless glyph in the set, and the one
    # that borrows its silhouette from whichever vowel it meets.
    "c_m": ["M30,50 L70,50"],
    "c_n": ["M30,32 L70,32", "M50,32 L50,68", "M30,68 L70,68"],
    # Two chevrons driven into each other until their vertices pass and the
    # arms cross twice. The same primitive the vowels are built from.
    "c_t": ["M74,24 L24,50 L74,76", "M26,24 L76,50 L26,76"],
    "c_d": ["M74,24 L24,50 L74,76", "M26,24 L76,50 L26,76", STEM],
    "c_th": [WAVE],
    "c_dh": [WAVE, STEM],
    "c_s": list(TALLY),
    "c_sh": [*TALLY, CROSSBAR],
    # Open, never closing, so it stays clear of the schwa's ring; and not a
    # chevron, so it stays clear of the vowels.
    "c_l": [HOOK],
    "c_r": [HOOK, CROSSBAR],
    # _|- : low arm left, up the stem, high arm right.
    "c_y": ["M26,72 L50,72 L50,28 L74,28"],
}
