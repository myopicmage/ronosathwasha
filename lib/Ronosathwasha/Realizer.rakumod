=begin pod

=head1 Ronosathwasha::Realizer

Meaning into a verb word.

This is the half of the round trip that has to be right about morphology.
Recognition can be forgiving, because a reader has the whole word in front of
them and the language is doing the work. Generation cannot: every alternant is
a choice, and choosing wrong produces a word that is writable, pronounceable
and wrong, which is the failure mode this language is least able to signal.

=head2 The stem governs, and it governs alone

Decision 2 and the repair recorded in the harmony decision put governance on
the stem: a front or neutral stem takes front alternants, a back stem takes
back ones. So the harmony class is computed once, from the stem, before any
affix is attached. Recomputing it as the word grows would be circular, and
computing it from the finished word would be wrong the moment a negator is
involved, because that morpheme is anti-harmonic by design and disagrees on
purpose.

=head2 Nothing here knows about negation

C<form-for> takes the stem's class and returns the form, and the declaration
already crossed the negator's alternants. So the negator is assembled by the
same three lines as the tense marker, and the one licensed disharmony in the
language costs no branch anywhere in this module.

=end pod

unit module Ronosathwasha::Realizer;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Morphology;
use Ronosathwasha::Harmony;
use Ronosathwasha::Semantics;

#| A stem with no harmony class cannot select an alternant, so a disharmonic
#| stem is not something to be realized around. It is a broken word.
class X::Realizer::NoClass is Exception is export {
    has Str $.stem is required;

    method message(--> Str) {
        "$!stem is neither front nor back, so no affix can agree with it"
    }
}

class X::Realizer::NoSuchMorpheme is Exception is export {
    has Str $.wanted is required;

    method message(--> Str) { "the declaration has no current morpheme $!wanted.raku()" }
}

#| Decision 16's order, stated once. The prefixes attach outermost first, so
#| this list is read left to right and the results concatenate in the same
#| direction.
my constant @PREFIX-ORDER = <modality polarity speech-act>;

my constant %TENSE-MORPHEME = (
    Past.key => 'past', Present.key => 'present', Future.key => 'future',
);

my constant %ACT-MORPHEME = (
    Interrogative.key => 'question', Imperative.key => 'command',
);

#| Build the verb word.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
sub realize-verb(
    Script:D     $script,
    Morphology:D $morphology,
    Str:D        $stem,
    SpeechAct:D :$speech-act = Declarative,
    Tense:D     :$tense      = Present,
    Aspect:D    :$aspect     = Simple,
    Polarity:D  :$polarity   = Affirmative,
    Modality:D  :$modality   = Asserted,
) is export {

    # Once, from the stem, before anything is attached. See the module
    # documentation for why this cannot be done later.
    my $class = profile-of($script, $stem);

    fail X::Realizer::NoClass.new(:$stem) if $class == MixedWord;

    my sub form(Str $id) {
        my $morpheme = $morphology.by-id($id);

        fail X::Realizer::NoSuchMorpheme.new(:wanted($id)) without $morpheme;

        $morpheme.form-for($class);
    }

    my %wanted =
        'modality'   => ($modality == Potential  ?? 'potential' !! Str),
        'polarity'   => ($polarity == Negative   ?? 'negation'  !! Str),
        'speech-act' => %ACT-MORPHEME{ $speech-act.key };

    my @prefixes = @PREFIX-ORDER.map({ %wanted{$_} }).grep(*.defined).map({ form($_) });

    my @suffixes = (
        form(%TENSE-MORPHEME{ $tense.key }),
        ($aspect == Continuous ?? form('continuous') !! Empty),
    );

    return (@prefixes, $stem, @suffixes).flat.join;

    CATCH { default { .fail } }
}

#| The full paradigm of one stem, which is the table Kevin asked for on
#| 2026-07-28. Returned as data rather than rendered, so a page and a terminal
#| can both use it.
sub paradigm(Script:D $script, Morphology:D $morphology, Str:D $stem --> Seq) is export {
    (
        past     => realize-verb($script, $morphology, $stem, :tense(Past)),
        present  => realize-verb($script, $morphology, $stem),
        future   => realize-verb($script, $morphology, $stem, :tense(Future)),
        command  => realize-verb($script, $morphology, $stem, :speech-act(Imperative)),
        question => realize-verb($script, $morphology, $stem, :speech-act(Interrogative)),
        might    => realize-verb($script, $morphology, $stem, :modality(Potential)),
        negative => realize-verb($script, $morphology, $stem, :polarity(Negative)),
    ).Seq;
}
