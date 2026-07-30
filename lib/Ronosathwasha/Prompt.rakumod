=begin pod

=head1 Ronosathwasha::Prompt

A C<PromptContext> as the message list a chat template renders.

=head2 Why messages and not the string that already exists

C<PromptContext.render> produces one ordered blob, and that is not what crosses the
boundary. C<CHATBOT.md> writes the pipeline out:

    Raku messages -> GGUF Jinja chat template -> text and control tokens -> tokenizer

C<llama-server --jinja> renders I<system>, I<user> and I<assistant> messages using the
template embedded in the GGUF, so the unit the model's own calling convention is
expressed in is a message, and a flat string would have to be smuggled in as a single
user turn. That works and throws away the one thing the template knows how to do.

So both survive, with different jobs, and neither is redundant:

=item C<render> is what a pure policy measures. C<Ronosathwasha::ContextPolicy> is
deterministic and its tests use C<PerWord>, so it needs a serialisation whose token
count does not move when a model changes.

=item C<messages> is what gets sent. Its real cost is only knowable by asking the
tokenizer what the template made of it, which is stop 7 and the reason the budget
currently underestimates.

=head2 What lands in which message

The invariants become the system message, together with the character. All three are
things the model needs before it can answer at all rather than things anybody said,
and a system message is exactly the slot a chat template has for that.

B<The folded summaries go there too, and that is a choice.> They are prose about
turns that no longer exist, so they are background rather than dialogue. Putting them
in the system message keeps the remaining turns a clean alternation of user and
assistant, which is what a chat template expects and what a model was trained on. The
alternative, injecting them as a pseudo-turn, invents an utterance nobody produced and
teaches the model that summaries are things speakers say.

The verbatim turns then map one to one: C<Human> becomes I<user> and C<Bot> becomes
I<assistant>.

=head2 The ordering is C<PromptContext>'s, not a new one

The system message is assembled in the order the invariants are declared, schema then
capabilities, which is the order they may be sacrificed in. Nothing here reorders
anything, because two files disagreeing about priority is how a policy stops meaning
what it says.

=end pod

unit module Ronosathwasha::Prompt;

use Ronosathwasha::Config;
use Ronosathwasha::ConversationState;
use Ronosathwasha::PromptContext;

#| The three slots a chat template has. Named for the template's vocabulary rather
#| than the conversation's, which is why this is not `Speaker`: that enum says who
#| was talking, and this says which slot a message occupies. A folded summary has a
#| slot and no speaker.
our enum MessageRole is export <System User Assistant>;

#| One message, as the template will receive it.
class Message is export {
    has MessageRole:D $.role    is required;
    has Str:D         $.content is required;

    #| The wire form, which is the OpenAI-compatible shape `llama-server` expects.
    #| Lowercased here rather than at the call site, so the one place that knows the
    #| protocol's spelling is the one place that knows the protocol.
    method for-wire(--> Hash) { %( role => $!role.key.lc, content => $!content ) }
}

#| The system message: who Lauri is, what the language can express, and what shape an
#| answer must take.
#|
#| Assembled in `PromptContext`'s declared order and not a new one. Sections are
#| labelled because a model reading four concatenated paragraphs has to guess where
#| the schema stops and the conversation summary starts, and guessing is what the
#| labels are for.
sub system-message(Config:D $config, PromptContext:D $context --> Message) is export {
    my @parts = $config.researcher.system.trim;

    @parts.push: "[{ .label }]\n{ .text }" for $context.invariants;

    # Background rather than dialogue. See the pod: a summary is not something a
    # speaker said, and giving it a turn would teach the model otherwise.
    @parts.push: "[remembered]\n" ~ $context.state.folded.join("\n")
        if $context.state.folded;

    Message.new(:role(System), :content(@parts.join("\n\n")));
}

#| The conversation, one message per surviving turn.
sub turn-messages(PromptContext:D $context --> List) is export {
    $context.state.turns.map(-> $turn {
        Message.new(
            :role($turn.speaker == Human ?? User !! Assistant),
            :content($turn.text),
        )
    }).List;
}

#| The whole prompt, in the order it is sent.
sub messages(Config:D $config, PromptContext:D $context --> List) is export {
    (system-message($config, $context), |turn-messages($context)).List;
}

#| The message list as `llama-server` wants it, ready for JSON encoding.
sub wire-messages(Config:D $config, PromptContext:D $context --> List) is export {
    messages($config, $context).map(*.for-wire).List;
}
