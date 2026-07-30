=begin pod

=head1 Ronosathwasha::ConversationState

What a conversation carries, and what it is allowed to forget.

C<CHATBOT.md> requires the system to keep five things apart: the passing
conversation, the current grammar, settled decisions, tentative experiments, and
retired rules kept for archaeology. This type is the first of those and only the
first. It holds turns.

=head2 Folding is lossy, on purpose, and says so

A conversation outgrows any context window, so old turns have to go. What
replaces them is a line of typed summary: enough that the model knows the topic
was discussed, not enough to reconstruct what was said.

That is fine for conversation and fatal for findings. A gap the model reported
twenty turns ago is the most valuable thing the exchange produced, and folding
would quietly throw it away.

So this class does not try to be clever about what it keeps. It exposes
C<gaps> so a caller can harvest before folding, and C<fold> plainly destroys
what it summarises. The alternative, a fold that tries to preserve everything
important, is a fold that fails silently the first time something important is
not on its list.

=head2 State is replaced, never mutated

Every method returns a new state. It makes a turn cheap to reason about, and it
means a context policy can try a fold, measure the result, and discard it
without having damaged anything.

Raku spells this C<.clone(:attr(...))>, which is F#'s C<{ r with X = 1 }> with
a longer name and no check that the field exists. So this class uses C<.with>
from L<Ronosathwasha::Checked> instead, which refuses a name it does not have
rather than returning a copy with nothing changed.

=end pod

unit module Ronosathwasha::ConversationState;

use Ronosathwasha::Types;
use Ronosathwasha::Checked;
use Ronosathwasha::Model;

our enum Speaker is export <Human Bot>;

#| One exchange. `meaning` is whatever the turn was understood to mean: a
#| `Reading` for something a person wrote, a `ResponseIntent` for something the
#| model chose. Undefined when the turn was not understood, which is ordinary
#| and worth keeping rather than dropping.
class Turn is export {
    has Speaker $.speaker is required;
    has Str     $.text    is required;
    has         $.meaning;

    method gist(--> Str) { "{ $!speaker.key.lc }: $!text" }
}

class ConversationState does Checked is export {
    has Turn @.turns;

    #| What older turns established, after their text was discarded. Prose on
    #| purpose: it is for a model to read, and nothing downstream parses it.
    has Str @.folded;

    method add(Turn:D $turn --> ConversationState) {
        self.with(:turns([|@!turns, $turn]));
    }

    method said(Speaker:D $speaker, Str:D $text, $meaning = Nil --> ConversationState) {
        self.add(Turn.new(:$speaker, :$text, :$meaning));
    }

    method last-turn(--> Turn) { @!turns.tail }

    #| Every gap anyone has reported, in order.
    #|
    #| Exposed so a caller can harvest before folding. This class will not
    #| preserve them for you, and a caller that folds without harvesting will
    #| lose them, which is the behaviour the tests pin down rather than a
    #| shortcoming to be fixed here.
    method gaps(--> Seq) {
        @!turns.map(*.meaning).grep({ $_ ~~ Gap });
    }

    #| Keep the newest `$keep` turns verbatim and summarise the rest.
    method fold(Int:D $keep --> ConversationState) {
        return self if @!turns.elems <= $keep;

        my @old = @!turns.head(@!turns.elems - $keep);
        my @new = @!turns.tail($keep);

        self.with(
            :turns(@new),
            :folded([|@!folded, |@old.map({ summarise($_) })]),
        );
    }

    method depth(--> Int) { @!turns.elems }
}

#| One line for a turn whose text is about to go.
#|
#| Deliberately thin. A richer summary would be a second, worse copy of the
#| turn, and the point of folding is that the turn is gone.
sub summarise(Turn:D $turn --> Str) is export {
    my $who = $turn.speaker.key.lc;

    given $turn.meaning {
        # `.tense.key` unguarded would die here on a timeless predication, which
        # carries no tense at all since decision 22. A summary is the wrong place
        # to learn that: it runs while folding, long after the turn it describes.
        when Express { "$who expressed { .predicate } ({ .tense.defined ?? .tense.key !! 'untensed' })" }
        when Gap     { "$who could not say { .wanted.raku }" }
        default      { "$who said something not understood" }
    }
}
