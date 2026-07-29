=begin pod

=head1 Ronosathwasha::Dialogue

One turn: read what was written, ask the model, write the answer.

=head2 The loop is the whole architecture, in order

Parse, decide, realize. The model sits in the middle and touches neither end:
it is handed meaning and returns meaning, and the Ronosathwasha on both sides is
produced by the grammar. Everything else in this project exists to make that
sentence true.

=head2 Nothing here decides anything about the language

A turn that cannot be read is recorded as unread. A model that reports a gap is
recorded as having reported one. Neither is repaired, guessed at, or approximated
here, because a chatbot that quietly papers over its failures produces a
conversation that reads well and teaches nothing.

=head2 Gaps are handed back, not stored

C<Exchange> carries the gap out to the caller. C<ConversationState> will lose it
at the next fold, deliberately and visibly, and the thing that keeps it is
C<LanguageEvidence>, which does not exist yet. Until it does, a caller that
throws away an C<Exchange> throws away the finding, and that is the honest state
of affairs rather than a hidden one.

=end pod

unit module Ronosathwasha::Dialogue;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Semantics;
use Ronosathwasha::Actions;
use Ronosathwasha::Realizer;
use Ronosathwasha::Sentence;
use Ronosathwasha::Model;
use Ronosathwasha::ConversationState;

#| Everything one turn produced, including the parts that failed.
class Exchange is export {
    has Str               $.heard         is required;
    has SentenceOutcome   $.understanding is required;
    has ResponseIntent    $.intent;
    has Str               $.said;
    has ConversationState $.state         is required;

    method understood(--> Bool) { so $!understanding ~~ Understood }

    method gap(--> Gap) { $!intent ~~ Gap ?? $!intent !! Gap }

    method summary(--> Str) {
        my $in  = self.understood ?? 'understood' !! $!understanding.summary;
        my $out = $!said.defined  ?? $!said       !! ($!intent andthen .summary orelse 'nothing');

        "$!heard -> $in -> $out"
    }
}

#| Build a sentence from an intent the model chose.
#|
#| Ordering is canonical here rather than preserved, and that is the difference
#| from `realize-sentence`. Rebuilding a sentence has an order somebody chose;
#| generating one has no source to respect, so decision 17's free positions are
#| filled subject first, then object, then the verb where it must be.
sub realize-intent(
    Script:D     $script,
    Morphology:D $morphology,
    Express:D    $intent,
) is export {
    my %case =
        Subject.key => $morphology.by-id('subject'),
        Object.key  => $morphology.by-id('object');

    my @order = ($intent.participants.grep(*.role == Subject),
                 $intent.participants.grep(*.role == Object)).flat;

    my @words = @order.map({
        realize-word($script, $morphology, [.stem], [%case{ .role.key }])
    });

    @words.push: realize-verb(
        $script, $morphology, $intent.predicate,
        :speech-act($intent.speech-act),
        :tense($intent.tense),
        :aspect($intent.aspect),
        :polarity($intent.polarity),
        :modality($intent.modality),
    );

    return @words.join(' ') ~ ($intent.speech-act == Interrogative ?? '?' !! '.');

    CATCH { default { .fail } }
}

#| Take one turn.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`. Only a
#| broken model reaches that: an unreadable input and an inexpressible meaning
#| are both ordinary results carried inside the `Exchange`.
sub take-turn(
    Script:D            $script,
    Lexicon:D           $lexicon,
    Morphology:D        $morphology,
    Model:D             $model,
    ConversationState:D $state,
    Str:D               $heard,
) is export {
    my $understanding = read-sentence($script, $lexicon, $morphology, $heard);

    my $meaning = $understanding ~~ Understood ?? $understanding.reading !! Nil;
    my $heard-state = $state.said(Human, $heard, $meaning);

    my $intent = $model.respond($heard-state);

    # A model that answers with something the declarations do not contain is a
    # broken model rather than a conversational event, so it propagates.
    #
    # Forced here, explicitly. Left alone, the inert failure reaches
    # `Exchange.new`, whose `ResponseIntent` attribute type-checks it, and the
    # binding error then replaces the exception that says what the model
    # actually sent. Third time this has happened; a constrained slot is where
    # a `Failure` goes to lose its cause.
    die $intent.exception if $intent ~~ Failure;

    my Str $said = $intent ~~ Express
        ?? realize-intent($script, $morphology, $intent)
        !! Str;

    return Exchange.new(
        :$heard,
        :$understanding,
        :$intent,
        :$said,
        :state($heard-state.said(Bot, $said // '', $intent)),
    );

    CATCH { default { .fail } }
}
