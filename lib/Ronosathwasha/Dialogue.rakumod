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
C<LanguageEvidence>. A caller that throws away an C<Exchange> throws away the
finding, and that is the honest state of affairs rather than a hidden one.

=head2 A turn carries the whole prompt, not just the conversation

C<take-turn> used to take a C<ConversationState> and hand it straight to the model.
It now takes a C<PromptContext>, which carries the invariants as well, and fits it
to a budget before asking. One parameter rather than four: the alternative was
passing the schema, the capabilities, the budget and the counter alongside the
state, and a ten-positional signature is its own kind of bug.

B<The fitted context is what goes forward, not the one that arrived.> Folding is
meant to be durable. C<ConversationState> accumulates its summaries and never
discards one, so carrying the unfolded context forward and refitting from scratch
each turn would do the same work repeatedly and, worse, would keep re-offering
turns the policy has already decided it cannot afford.

The bot's turn is added after the fit, so the context handed back may itself be
over budget. That is correct and self-correcting: the next turn begins by fitting
it again.

=head2 A window too small is not a conversational event

C<fit-context> refuses rather than truncating, and that refusal propagates the same
way a model naming a nonexistent word does. An unreadable input and an
inexpressible meaning are ordinary results carried inside the C<Exchange>; a
prompt that cannot be assembled is a broken configuration.

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
use Ronosathwasha::Intent;
use Ronosathwasha::Model;
use Ronosathwasha::ConversationState;
use Ronosathwasha::PromptContext;
use Ronosathwasha::ContextPolicy;
use Ronosathwasha::TokenCounter;

#| Everything one turn produced, including the parts that failed.
class Exchange is export {
    has Str             $.heard         is required;
    has SentenceOutcome $.understanding is required;
    has ResponseIntent  $.intent;
    has Str             $.said;

    #| The prompt as it stands after this turn: fitted, with the bot's answer
    #| added. Feed it straight back into the next `take-turn`.
    has PromptContext:D $.context is required;

    #| The conversation inside it. A method rather than a second attribute, so
    #| there is no way to hold a state that disagrees with the context holding it.
    method state(--> ConversationState) { $!context.state }

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
#|
#| The question is written once, wherever the scope puts it, which is the same
#| rule `realize-sentence` follows and half the same code: `act-to-write` decides
#| for the predicate, and the constituent side applies the identical precedence,
#| marker unless the stem already spells one.
sub realize-intent(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Express:D    $intent,
) is export {
    my %case =
        Subject.key => $morphology.by-id('subject'),
        Object.key  => $morphology.by-id('object');

    my @order = ($intent.participants.grep(*.role == Subject),
                 $intent.participants.grep(*.role == Object)).flat;

    # Which participant the marker lands on, when it lands on one at all. The
    # scope-to-role reading also appears in `intent-from`'s carrier check, which
    # guarantees the participant this looks for exists.
    my Argument $marked = do given $intent.question-scope {
        when QuestionsSubject { Subject }
        when QuestionsObject  { Object }
        default               { Argument }
    };

    my $question = $morphology.by-id('question');

    my @words = @order.map(-> $p {
        # Unless the stem already spells it: `toro` is "who" with the question
        # inside, and prefixing it again gives `totoro`, which is a film. The
        # same precedence `act-to-write` applies to the predicate, read from the
        # same declaration.
        my Bool $questioned = $marked.defined
            && $p.role == $marked
            && not $lexicon.interrogative-words{ $p.stem };

        realize-word($script, $morphology, [$p.stem], [%case{ $p.role.key }],
            :prefixes($questioned ?? [$question] !! []));
    });

    my SpeechAct $act = act-to-write($lexicon, $intent);

    # The copularizer is always written when generating, which is the same choice
    # this sub already makes about word order: rebuilding a sentence respects what
    # somebody wrote, and generating one has nothing to respect. Decision 22 lets
    # ordinary speech drop the copula, so `Express` has no field for the omission
    # and generation takes the explicit form.
    @words.push: $intent.nominal-predicate
        ?? realize-nominal-predicate(
               $script, $morphology, $intent.predicate,
               :speech-act($act),
               :tense($intent.tense),
               :aspect($intent.aspect),
               :polarity($intent.polarity),
               :modality($intent.modality),
           )
        !! realize-verb(
               $script, $morphology, $intent.predicate,
               :speech-act($act),
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
    Script:D        $script,
    Lexicon:D       $lexicon,
    Morphology:D    $morphology,
    Model:D         $model,
    PromptContext:D $context,
    Budget:D        $budget,
    TokenCounter:D  $counter,
    Str:D           $heard,
) is export {
    my $understanding = read-sentence($script, $lexicon, $morphology, $heard);

    my $meaning = $understanding ~~ Understood ?? $understanding.reading !! Nil;
    my $heard-context = $context.with(
        :state($context.state.said(Human, $heard, $meaning)),
    );

    # Fitted before the model is asked, on the state that includes what was just
    # heard, because the turn being answered is the one that must not be folded.
    #
    # Forced here for the same reason the intent is below: an inert `Failure`
    # handed to `Exchange.new`'s constrained `PromptContext` attribute is
    # type-checked, and the binding error then replaces the exception that says the
    # window was too small.
    my $fitted = fit-context($heard-context, $budget, $counter);
    # `.defined` rather than `~~ Failure`, and the difference is not style. Smartmatching
    # against a type does not mark a `Failure` handled and neither does `.exception`, so
    # the old form retrieved the cause, rethrew it, and left the original object to
    # complain at destruction: "unhandled Failure detected in DESTROY". `.defined` is one
    # of the four methods that mark it, along with `.Bool`, `.so` and `.not`.
    die $fitted.exception unless $fitted.defined;

    my $intent = $model.respond($fitted);

    # A model that answers with something the declarations do not contain is a
    # broken model rather than a conversational event, so it propagates.
    #
    # Forced here, explicitly. Left alone, the inert failure reaches
    # `Exchange.new`, whose `ResponseIntent` attribute type-checks it, and the
    # binding error then replaces the exception that says what the model
    # actually sent. Third time this has happened; a constrained slot is where
    # a `Failure` goes to lose its cause.
    die $intent.exception unless $intent.defined;

    my Str $said = $intent ~~ Express
        ?? realize-intent($script, $lexicon, $morphology, $intent)
        !! Str;

    return Exchange.new(
        :$heard,
        :$understanding,
        :$intent,
        :$said,
        :context($fitted.with(:state($fitted.state.said(Bot, $said // '', $intent)))),
    );

    CATCH { default { .fail } }
}
