=begin pod

=head1 Ronosathwasha::PromptContext

Everything a model is handed on one turn, in the order it may be sacrificed.

=head2 The role's C<$context> had no type, and this is it

C<Ronosathwasha::Model> declares C<method respond($context --> ResponseIntent)>
with the parameter deliberately unconstrained, and C<Dialogue.take-turn> has been
passing a bare C<ConversationState>. That worked while a turn was the only thing a
model needed to see, and it stops working the moment there is a window to fit
inside, because a conversation is the part that has to give way and it is not the
only part that is sent.

So a prompt has two kinds of content and the difference is the whole design:

=item B<Invariants> are the parts whose absence makes the answer worthless. The
response schema, because a model that has not been told the shape cannot be parsed
into a C<ResponseIntent>. The language capabilities, because a model that has not
been told what the language can express will invent something it cannot.

=item B<The conversation> is the part that can be shortened, and
C<ConversationState.fold> already knows how: the oldest turns become a line of
summary each and their text goes.

An invariant is never dropped and never trimmed. If it does not fit, that is a
configuration error and C<Ronosathwasha::ContextPolicy> says so rather than
sending a prompt with a hole in it.

=head2 C<PromptInvariant>, not C<Invariant>

C<Ronosathwasha::Types> already exports C<Invariant> as one of C<Alternation>'s
values, meaning a morpheme with no backness to agree about. Raku installs an
enum's values as symbols in the importing scope, so a class of that name here does
not shadow it or lose to it: any module importing both simply fails to compile,
naming the second C<use> and not the enum.

Fourth time this shape has bitten in this distribution. C<VowelProfile> is
suffixed for it, C<FindingKind> is flattened for it, and the exceptions are rooted
rather than nested for it. The prefix is the same fix.

=head2 Why the two invariants are one type rather than two C<Str>s

Both are text and both are mandatory, which makes them the same kind of thing, and
the policy has to be able to walk them to report which one it could not afford.
Two bare string attributes force that failure message to be written by hand at
every site, and a message written by hand is a message that eventually names the
wrong field.

C<Invariant> carries its own label, so the failure says
C<the response schema does not fit> without the policy holding a table of names.

=head2 Language evidence is not here, and that is deliberate

C<Ronosathwasha::LanguageEvidence> makes the case in full: findings are the most
valuable output the conversation produces, and anything in the rolling prompt is
by definition something the window can take away. Evidence lives outside, is
harvested before folding, and survives the turn that produced it scrolling off.

The temptation is real, because putting recent findings in the prompt would let
the model avoid repeating a gap it already reported. That is a feature to build
deliberately if it is wanted, out of evidence held elsewhere, and never a reason
to move the store into the thing that forgets.

=head2 Rendering is model-agnostic on purpose

C<render> produces a plain, ordered serialisation. It is not a chat template and
does not pretend to be one: C<llama.cpp> has opinions about system and user roles
and about which special tokens frame them, and those arrive in stop 9's
C<Prompt.rakumod> along with a tokenizer that actually knows the model.

What this gives C<ContextPolicy> is something stable to measure. The policy is
pure and its tests use C<PerWord>, so a serialisation whose token count changes
with the model would make boundary behaviour untestable.

=end pod

unit module Ronosathwasha::PromptContext;

use Ronosathwasha::Checked;
use Ronosathwasha::ConversationState;

#| One piece of prompt that may not be shortened, and what to call it when it
#| does not fit.
class PromptInvariant is export {
    has Str:D $.label is required;
    has Str:D $.text  is required;
}

class PromptContext does Checked is export {

    #| What shape the answer must take. First because a well-informed model that
    #| cannot be parsed has produced nothing at all.
    has PromptInvariant:D $.schema is required;

    #| What the language can currently express. Second because this is what keeps
    #| a gap honest: a model that does not know the boundary reaches past it and
    #| calls the result Ronosathwasha.
    has PromptInvariant:D $.capabilities is required;

    #| The turns, and the summaries of the turns that are gone. Held rather than
    #| copied apart, so folding is `ConversationState`'s single implementation and
    #| the policy replaces the state instead of maintaining a second copy of it.
    has ConversationState:D $.state is required;

    #| The two, in the order they were declared, which is the order they matter.
    #|
    #| A method rather than an attribute so it cannot drift out of step with the
    #| fields, and so `with` cannot be handed a list that disagrees with them.
    method invariants(--> List) { ($!schema, $!capabilities) }

    #| The floor: what is sent when the conversation has been given away entirely.
    #|
    #| This is the quantity a budget is checked against before any folding is
    #| attempted, because no amount of folding moves it.
    method invariant-text(--> Str) {
        self.invariants.map({ "[{ .label }]\n{ .text }" }).join("\n\n");
    }

    #| The conversation as the model reads it: what is remembered, then what was
    #| said, oldest first.
    #|
    #| Empty rather than a heading with nothing under it, so a first turn does not
    #| spend tokens announcing that nothing has happened yet.
    method conversation-text(--> Str) {
        my @parts;

        @parts.push: "[remembered]\n" ~ $!state.folded.join("\n") if $!state.folded;
        @parts.push: "[conversation]\n" ~ $!state.turns.map(*.gist).join("\n")
            if $!state.turns;

        @parts.join("\n\n");
    }

    #| Everything, invariants first.
    method render(--> Str) {
        (self.invariant-text, self.conversation-text).grep(*.chars).join("\n\n");
    }

    #| How many verbatim turns are still in here. The policy's lever.
    method depth(--> Int) { $!state.depth }
}
