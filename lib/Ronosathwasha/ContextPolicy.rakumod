=begin pod

=head1 Ronosathwasha::ContextPolicy

Fit a prompt to a budget, or say why it cannot be done.

=head2 Deciding here beats discovering at generation time

A prompt that fills the window leaves nothing for the answer, and the symptom
arrives late and disguised: the model returns a truncated or refused response, and
what it looks like is a bad model. C<Budget> already separates the window from
what a prompt may spend. This is the thing that respects it.

There is exactly one way to make a prompt smaller here, and it is
C<ConversationState.fold>. Nothing truncates an utterance and nothing drops an
invariant, so the only lever is how many turns stay verbatim.

=head2 Folding is not monotonic, which is why this scans

The obvious implementation is a binary search on how many turns to keep. It is
unsound, and by a wider margin than it first looks.

Folding removes a turn's text and adds a line of summary, so it pays only when the
turn was longer than the line. C<summarise> renders a turn nobody understood as
C<human said something not understood>: five words, against a gist of three for a
short one. Measured on three short unread turns under C<PerWord>, the prompt costs
20 verbatim and B<26> folded. Folding made it half again as expensive.

So cost is not monotonic in how much is folded, it is not even reliably decreasing,
and a search assuming either would report "does not fit" about a context that does.
Whether folding helps at all is a property of the turns, not of the policy.

So the scan is linear and runs from most verbatim turns to fewest, returning the
first arrangement that fits. Linear also gets the preference right for free: the
first fit is the one that keeps the most conversation, which is the priority order
C<PromptContext> declares.

=head2 The cost of the scan, honestly

Each attempt renders and counts. With C<PerWord> that is arithmetic. With the real
tokenizer in stop 9 it is a call per attempt, and a long conversation that has just
overflowed will make several.

That is a real cost and it is not paid down by binary search, for the reason above.
The available fixes are caching a count per turn and folding by more than one turn
at a time, and neither is worth writing before a profile says which.

=head2 Two failures, not one

A context that cannot fit raises rather than returning a smaller thing that
happens to fit, because there is no smaller thing that is still the prompt.

C<Window::Invariants> means the mandatory material alone exceeds the budget. No
conversation, however short, will make room. That is configuration: the window is
too small, or the schema and capabilities have grown.

C<Window::Conversation> means every turn is folded and it still does not fit. The
accumulated summary has outgrown the window, which is a genuine runtime condition
rather than a misconfiguration, because folding adds a line each time it removes a
turn and C<ConversationState> never discards one.

=end pod

unit module Ronosathwasha::ContextPolicy;

use X::Ronosathwasha;

use Ronosathwasha::PromptContext;
use Ronosathwasha::TokenCounter;

#| What an arrangement of a context costs.
#|
#| Separate from `fit-context` so a caller can ask before committing, and so the
#| tests can calibrate a budget against a real count rather than against
#| hand-arithmetic that goes stale the moment `render` changes.
sub context-cost(PromptContext:D $context, TokenCounter:D $counter --> Int) is export {
    $counter.count($context.render);
}

#| The smallest this context can be made: every turn folded away.
sub folded-flat(PromptContext:D $context --> PromptContext) is export {
    $context.with(:state($context.state.fold(0)));
}

#| Fit a context to a budget by folding, or refuse.
#|
#| No return type, so a refusal stays inert; see `X::Ronosathwasha` on the two
#| strategies. This is a domain refusal rather than infrastructure: a window too
#| small for a conversation is something a caller may want to report to Kevin
#| rather than something that should abort a session.
sub fit-context(
    PromptContext:D $context,
    Budget:D        $budget,
    TokenCounter:D  $counter,
) is export {

    # The floor first, because it is the one answer no amount of folding changes.
    # Checking it up front also means the scan below cannot spend a call per turn
    # discovering the same thing once per turn.
    my Int $floor = $counter.count($context.invariant-text);

    die X::Ronosathwasha::Window::Invariants.new(
        :available($budget.available),
        :cost($floor),
        :labels($context.invariants.map(*.label).List),
    ) unless $budget.fits($floor);

    # Most verbatim turns first, so the first fit is also the most conversation
    # kept. `fold` is a no-op when there is nothing older than `$keep`, so the
    # first iteration measures the context as it arrived.
    for $context.depth ... 0 -> $keep {
        my $try = $context.with(:state($context.state.fold($keep)));

        return $try if $budget.fits(context-cost($try, $counter));
    }

    my $flat = folded-flat($context);

    die X::Ronosathwasha::Window::Conversation.new(
        :available($budget.available),
        :cost(context-cost($flat, $counter)),
        :folded($flat.state.folded.elems),
    );

    CATCH { default { .fail } }
}
