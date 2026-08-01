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

=head2 A nominal predicate takes the same prefixes a verb does

Until review C<021>'s first finding, it took none. C<Express> accepted a polarity
and a modality, C<intent-from> checked them, they survived into a well-typed value,
and C<realize-nominal-predicate> had no parameter to receive them, so
C<laarisweme> came out for the negative potential and the plain assertion alike.
Not rejected and not approximated: discarded, silently, in a signature.

Kevin's ruling settles what the missing forms are, and it is the least surprising
answer available: the same three prefixes, meaning the same three things.
C<molaariswe> is "is not laari" and C<Nari temirireswe?> is "are you a teacher".
The negator, the potential and the question marker do not care what they attach
to, and C<prefix-ids> below is now the single list both realizers read.

What is B<not> here yet is the guard against writing a marker a stem already
spells. C<toro> is the word for "who" and prefixing a question marker to it would
give C<totoro>, so the interrogative words need a check against
C<data/lexicon.toml>, which this module does not currently receive. Nothing passes
C<:speech-act> to a nominal predicate yet, so the hazard is not reachable; it is
noted because the parameter is now there to be passed.

=head2 Nothing here knows about negation

C<form-for> takes the stem's class and returns the form, and the declaration
already crossed the negator's alternants. So the negator is assembled by the
same three lines as the tense marker, and the one licensed disharmony in the
language costs no branch anywhere in this module.

=end pod

unit module Ronosathwasha::Realizer;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Morphology;
use Ronosathwasha::Harmony;
use Ronosathwasha::Semantics;



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

#| One morpheme's form for a stem of this class.
#|
#| Was a closure inside `realize-verb`, which is why the nominal predicate reached
#| for `$morphology.by-id` directly and got no missing-morpheme check at all.
sub form-of(Morphology:D $morphology, Str:D $id, VowelProfile:D $class) {
    my $morpheme = $morphology.by-id($id);

    fail X::Ronosathwasha::Form::NoSuchMorpheme.new(:wanted($id)) without $morpheme;

    $morpheme.form-for($class);
}

#| Which prefixes the three prefixing axes call for, in decision 16's order.
#|
#| Shared rather than written twice, and that is the whole point of extracting it:
#| a verb and a nominal predicate take the same three prefixes, and the only reason
#| they ever differed is that this list lived inside `realize-verb` where the other
#| one could not reach it.
#|
#| Two of the three are unmarked in one of their values, so the list is usually
#| shorter than three and is empty for an ordinary declarative statement.
sub prefix-ids(
    SpeechAct:D $speech-act,
    Polarity:D  $polarity,
    Modality:D  $modality,
    QuestionKind:D $question-kind,
    --> Seq
) {
    my %wanted =
        'modality'   => ($modality == Potential  ?? 'potential' !! Str),
        'polarity'   => ($polarity == Negative   ?? 'negation'  !! Str),
        'speech-act' => $speech-act == Interrogative && $question-kind == SelectiveQuestion
            ?? 'selective-question'
            !! %ACT-MORPHEME{ $speech-act.key };

    @PREFIX-ORDER.map({ %wanted{$_} }).grep(*.defined);
}

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
    QuestionKind:D :$question-kind = OpenQuestion,
) is export {

    # Once, from the stem, before anything is attached. See the module
    # documentation for why this cannot be done later.
    my $class = profile-of($script, $stem);

    fail X::Ronosathwasha::Form::NoClass.new(:$stem) if $class == MixedWord;

    my @prefixes = prefix-ids($speech-act, $polarity, $modality, $question-kind);

    my @suffixes = (
        %TENSE-MORPHEME{ $tense.key },
        ($aspect == Continuous ?? 'continuous' !! Empty),
    );

    return (
        @prefixes.map({ form-of($morphology, $_, $class) }),
        $stem,
        @suffixes.map({ form-of($morphology, $_, $class) }),
    ).flat.join;

    CATCH { default { .fail } }
}

#| Build a nominal predicate. The copularizer is optional in ordinary unmarked
#| identity clauses; tense is optional independently because writing present tense
#| contributes the contrastive "right now" reading.
#|
#| `Tense :$tense` rather than `Tense:D :$tense = Present` beside a separate
#| `:$explicit-tense` flag. The two said the same thing twice, and a `:D` with a
#| default cannot express "no tense" at all: it turns the absence into an
#| assertion of the present, which is the reading decision 22 exists to
#| distinguish. Undefined now means untensed, and there is one place to get it
#| wrong instead of two to keep in step.
sub realize-nominal-predicate(
    Script:D     $script,
    Morphology:D $morphology,
    Str:D        $stem,
    Bool:D      :$copularized = True,
    SpeechAct:D :$speech-act  = Declarative,
    Tense       :$tense,
    Aspect:D    :$aspect      = Simple,
    Polarity:D  :$polarity    = Affirmative,
    Modality:D  :$modality    = Asserted,
    QuestionKind:D :$question-kind = OpenQuestion,
) is export {
    my $class = profile-of($script, $stem);

    fail X::Ronosathwasha::Form::NoClass.new(:$stem) if $class == MixedWord;
    fail X::Ronosathwasha::Form::UntensedAspect.new(:aspect<continuous>)
        if $aspect == Continuous && not $tense.defined;

    my @suffixes;
    @suffixes.push: 'copularizer' if $copularized;
    @suffixes.push: %TENSE-MORPHEME{ $tense.key } if $tense.defined;
    @suffixes.push: 'continuous' if $aspect == Continuous;

    return (
        prefix-ids($speech-act, $polarity, $modality, $question-kind)
            .map({ form-of($morphology, $_, $class) }),
        $stem,
        @suffixes.map({ form-of($morphology, $_, $class) }),
    ).flat.join;

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
