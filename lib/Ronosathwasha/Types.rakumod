=begin pod

=head1 Ronosathwasha::Types

The vocabulary every other module speaks. Nothing here reads a file or makes a
decision; these are the shapes that make a wrong statement about the language
hard to write down.

=end pod

unit module Ronosathwasha::Types;

# The exceptions this project raises live in `X::Ronosathwasha`, rooted rather
# than nested, so that `X::Ronosathwasha::Declaration::Unreadable` reads as ours
# and `X::TypeCheck::Binding::Parameter` reads as the language's. See that file
# for the two behaviours of `Failure` that the loaders here depend on.

use X::Ronosathwasha;

#| The backness of a single vowel. The values are exactly the strings
#| `data/script.toml` uses, because the script draws backness as direction and
#| that file is where the direction is declared. Translating the vocabulary at
#| the boundary would create a second name for one fact.
our enum Backness is export <Front Back Central>;

#| The backness of a whole word, which is a different question from the
#| backness of a vowel and deserves a different type. A word can be `MixedWord`
#| and a vowel cannot be anything of the kind.
#|
#| The names are suffixed rather than sharing `Front` and `Back` with
#| `Backness`. Raku installs an enum's values as symbols in the importing
#| scope, so two enums offering the same value name collide at `use` time
#| rather than at the call site, and the error does not mention either enum.
our enum VowelProfile is export <FrontWord BackWord NeutralWord MixedWord>;

#| Whether a word obeys harmony. `LicensedDisharmony` is not a gentler
#| `Violates`: it carries the rule that permits the form. Anti-harmonic
#| negation is the only licence the language currently grants, and a correctly
#| negated word has to stay distinguishable from an accident.
our enum HarmonyJudgment is export <Harmonic LicensedDisharmony Violates>;

#| Whether a form is still the language's answer. `Superseded` is the
#| load-bearing one: a retired form is dangerous precisely when it is still
#| writable, because nothing in the font or the keyboard will object to it.
our enum LanguageStatus is export <Current Superseded Undecided>;

#| Whether a form can be written at all. Decision 1 dropped the affricates and
#| took `j` and `ch` with them, so some retired forms are unreachable by
#| accident rather than by design.
our enum OrthographyStatus is export <Writable NeedsRespelling>;

#| Which side of its host a morpheme attaches to. This is the only thing that
#| separated present-tense `me` from the negator before `data/morphology.toml`
#| existed, and it was separating them in a comment.
our enum Position is export <Prefix Suffix>;

#| How a morpheme's form responds to its host.
#|
#| `Invariant` and `Unpaired` are both "one form", and collapsing them loses
#| the reason. Invariant means the morpheme has no backness to agree about,
#| which is `sa`. Unpaired means one form where two were needed, which is what
#| made `yo`, `tho`, `ju`, `je` and `ji` replaceable.
our enum Alternation is export <Alternating AntiHarmonic Invariant Unpaired>;

#| What grammatical job a morpheme does.
#|
#| The values are verbs rather than the bare category names, because the
#| categories themselves are enum types in `Ronosathwasha::Semantics`, where a
#| tense is `Past`, `Present` or `Future`. Since Raku installs enum values as
#| symbols in the importing scope, a value named `Tense` here would collide
#| with the type named `Tense` there for any module using both, and that is
#| every module downstream of this one.
#| `MarksPredication` rather than `FormsPredicate`, and the distinction it gives up
#| is real: every other value marks a feature of a predicate, while a copularizer
#| brings one into being out of a nominal. Uniform prefixes win anyway. The prefix
#| is not decoration, it is what keeps these names out of the way of `Semantics`,
#| and a set where ten values announce that and one does not is a set where the
#| eleventh reads as an oversight.
our enum MorphemeRole is export <
    MarksTense MarksAspect MarksPolarity MarksSpeechAct MarksModality
    MarksCase MarksNumber MarksPossession MarksNonfinite MarksLocative
    MarksPredication
>;

#| What a morpheme attaches to.
our enum Host is export <VerbStem NominalStem NounStem>;
