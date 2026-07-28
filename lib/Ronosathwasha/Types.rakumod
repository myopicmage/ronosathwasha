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

=begin pod

=head2 Failures

Reading a declaration is where this program meets the outside world, so a
missing or malformed file is an ordinary outcome rather than a bug.

These are typed exceptions carrying structured fields, raised with C<fail>.
That combination is Raku's own two-track mechanism: C<fail> returns an inert
C<Failure> instead of throwing, so the failure site does not unwind, and the
value only throws if something tries to use it. A caller that wants to inspect
asks C<.defined>; a caller that does not need to know anything writes no guard
at all and the failure propagates by itself.

The information is what makes it railway-oriented, not the shape of the
container. Each class below carries the fields needed to say what went wrong
and where, so nothing has to be recovered by reading a message.

Two behaviours to know, because both are invisible until they bite:

=item A declared return type defeats C<fail>. A sub written C<sub f(--> Script)>
      throws at the C<fail> rather than returning a C<Failure>, because the
      constraint rejects the C<Failure> on the way out. Loaders here therefore
      declare no return type.

=item Propagation travels by method dispatch, not by parameter binding. Calling
      any method on a C<Failure> throws the exception it carries, reliably,
      whether it arrived directly or out of a variable. That is what lets the
      loaders chain without guards.

=item A narrow parameter type breaks that, and quietly. Passing a C<Failure>
      straight from a call into a C<RawDocument:D> parameter does unwrap to the
      original exception, but passing the same failure through a scalar
      variable first throws C<X::TypeCheck::Binding::Parameter> instead, and
      the original cause is gone. One intermediate C<my $doc = ...> is the
      whole difference. Parameters that may receive a possibly-failed value are
      therefore left unconstrained here, and the failure surfaces on first use.

=end pod

#| Base for anything wrong with a declaration file. Catching this catches every
#| way a declaration can be unusable, which is the granularity a caller
#| loading several files actually wants.
#|
#| Subclasses below reach `path` as `$.path` rather than `$!path`. The
#| twigils are not interchangeable: `$!` is the attribute itself and is private
#| to the class that declared it, so it is not in scope in a subclass at all.
#| `$.` is the generated accessor, which is inherited like any other method.
class X::Declaration is Exception is export {
    has IO::Path $.path is required;
}

#| The file could not be read or parsed at all.
class X::Declaration::Unreadable is X::Declaration is export {
    has Str $.reason is required;

    method message(--> Str) { "could not read $.path: $!reason" }
}

#| The file parsed, and does not contain something required.
class X::Declaration::MissingTable is X::Declaration is export {
    has Str $.table is required;

    method message(--> Str) { "$.path has no [$!table]" }
}

#| A declared value is outside the set this code understands. Not a default and
#| not a warning: a backness of "fornt" is a typo that would otherwise become a
#| harmony class.
class X::Declaration::BadValue is X::Declaration is export {
    has Str $.field   is required;
    has Str $.subject is required;
    has     $.found;

    method message(--> Str) {
        "$.path: $!subject has $!field { $!found.raku }, which is not declared"
    }
}
