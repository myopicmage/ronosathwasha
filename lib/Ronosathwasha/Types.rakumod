=begin pod

=head1 Ronosathwasha::Types

The vocabulary every other module speaks. Nothing here reads a file or makes a
decision; these are the shapes that make a wrong statement about the language
hard to write down.

=end pod

unit module Ronosathwasha::Types;

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
our enum Role is export <
    Tense Aspect Polarity SpeechAct Modality
    Case Number Possession Nonfinite Locative
>;

#| What a morpheme attaches to.
our enum Host is export <VerbStem NominalStem NounStem>;

#| Everything a loader may return.
#|
#| Raku has no discriminated unions, so a closed set of outcomes is built from
#| a role the members share. Compared to an F# DU this gives up exhaustiveness
#| checking: nothing tells you a `when` chain missed a case. What it keeps is
#| the part that matters at a boundary, which is that a signature can promise
#| `LoadOutcome` and a caller cannot receive a bare hash by accident.
role LoadOutcome is export { }

#| A load that did not happen, as a value rather than an exception. Reading a
#| declaration is the one place this program touches the outside world, and a
#| missing or malformed file is an ordinary thing for the outside world to be.
#| `$.path` stays an `IO::Path` rather than a string. The narrower type is the
#| one that was already in hand, and storing it means no call site has to
#| stringify to construct a failure. Raku's other tool here is a coercion
#| attribute, `has Str() $.path`, which accepts the `IO::Path` and stores the
#| string; that is the right move when the string really is what you want.
class LoadFailure does LoadOutcome is export {
    has IO::Path $.path   is required;
    has Str      $.reason is required;

    method gist(--> Str) { "could not load $!path: $!reason" }
    method Str(--> Str)  { self.gist }
}
