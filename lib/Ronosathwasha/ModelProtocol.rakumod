=begin pod

=head1 Ronosathwasha::ModelProtocol

The contract with a model: two capabilities, and the shape an answer must take.

=head2 Two roles, so the pure half stays testable

Inference and tokenization are separate capabilities and both are needed. Keeping
them behind roles is what lets C<Ronosathwasha::ContextPolicy> stay deterministic and
independently testable: it takes a counter, and whether that counter is arithmetic or
an HTTP request to a server holding ten gigabytes of weights is not its business.

C<Inference> sends messages and returns whatever the model answered, still raw.
C<PromptTokenizer> answers how much a message list costs, which is a different
question from how much a string costs and the reason C<TokenCounter> is not enough.

=head2 Why a message list needs its own counter

C<Ronosathwasha::TokenCounter> counts a C<Str>, and the string a policy measures is
not the string a model receives. C<CHATBOT.md> writes the pipeline out: messages go
through the GGUF's Jinja template, which adds role framing and control tokens, and
only then are tokenized.

So the honest count needs both surfaces, and llama.cpp exposes them separately:
apply the template to the messages, then tokenize the result. A counter that takes a
string cannot do the first step, which is why this role takes the list.

=head2 The schema constrains the predicate to the lexicon

This is the part worth the file. C<response_format> can carry a JSON schema, and the
schema's C<predicate> is not C<{ "type": "string" }>: it is an enumeration of exactly
the stems C<nameable> reports, currently 88 of them. B<A model cannot name a word the
language does not have, because the decoder will not emit the tokens.>

C<intent-from> checks the same thing again afterwards, and that is deliberate rather
than redundant. Plan C<014> asks for it in those words: reject unknown fields or
invalid combinations even when the server claims schema success. A constrained decoder
can guarantee the shape of JSON and cannot guarantee that a server honoured the
constraint, that a future server will, or that the combination of two individually
legal fields means anything.

C<additionalProperties> is false, which is the same refusal at the schema level: a
field nobody asked for is a model answering a different question.

=head2 What the schema cannot express, and who catches it

An absent tense is legal only on a nominal predicate, because a verb without a tense
morpheme is not a word. JSON Schema can say that with C<if>/C<then>, and llama.cpp
converts a schema into a grammar, so the more of that conversion a schema leans on the
more ways there are for it to be quietly unsupported.

So the schema leaves C<tense> optional and says nothing about the pairing, and
C<intent-from> refuses the combination with a message naming it. The rule lives in one
place either way, and this is the place that cannot be silently unsupported.

=end pod

unit module Ronosathwasha::ModelProtocol;

use Ronosathwasha::Config;
use Ronosathwasha::Intent;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::PromptContext;

#| Ask a model to answer. Returns the raw decoded JSON object, unvalidated: turning
#| it into an intent is `intent-from`'s job and refusing it is `intent-from`'s right.
role Inference is export {
    method complete(@messages --> Hash) { ... }
}

#| How many tokens a message list costs once the model's own template has framed it.
role PromptTokenizer is export {
    method count-prompt(@messages --> Int) { ... }
}

#| One field of the answer, as a JSON Schema fragment.
sub enumerated(@values --> Hash) { %( type => 'string', enum => @values.List ) }

#| The schema a model's answer must satisfy.
#|
#| Built from `answer-vocabulary` and `nameable` rather than written out, so the
#| strings the decoder accepts and the strings the schema permits cannot drift apart.
sub response-schema(Lexicon:D $lexicon, Morphology:D $morphology --> Hash) is export {
    my %v = answer-vocabulary();
    my @stems = nameable($lexicon, $morphology).keys.sort;

    %(
        type => 'object',
        additionalProperties => False,

        # Only the discriminator. Everything else depends on which kind it is, and a
        # schema that required `predicate` would make a gap impossible to express,
        # which is the one answer this project most wants available.
        required => ['kind'],

        properties => %(
            kind => enumerated(%v<kind>),

            # An enumeration and not a string. This is the line that makes an
            # invented word unsayable rather than merely rejected.
            predicate  => enumerated(@stems),

            speech_act => enumerated(%v<speech_act>),
            aspect     => enumerated(%v<aspect>),
            polarity   => enumerated(%v<polarity>),
            modality   => enumerated(%v<modality>),

            # Absent for a timeless identity, which decision 22 made a meaning rather
            # than an omission. The pairing rule is not expressed here; see the pod.
            tense => enumerated(%v<tense>),

            nominal_predicate => %( type => 'boolean' ),

            arguments => %(
                type  => 'array',
                items => %(
                    type => 'object',
                    additionalProperties => False,
                    required => ['role', 'stem'],
                    properties => %(
                        role => enumerated(%v<role>),
                        stem => enumerated(@stems),
                    ),
                ),
            ),

            # Free text, and the only free text in the schema. A gap is the model
            # telling Kevin something the declarations cannot express, so constraining
            # it to declared vocabulary would make it unable to say what is missing.
            wanted  => %( type => 'string' ),
            missing => %( type => 'string' ),
        ),
    );
}

#| The chat-completions request body, ready for JSON encoding.
#|
#| Assembled here rather than in the client, because what goes on the wire is part of
#| the contract and the client's job is transport. A contract test can then assert the
#| exact body without a socket.
sub request-body(
    Config:D     $config,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    @messages,
    --> Hash
) is export {
    %(
        messages => @messages.List,
        temperature => $config.sampling.temperature,
        top_p       => $config.sampling.top-p,
        top_k       => $config.sampling.top-k,

        # The reservation, and the only place it is spent. `Budget.reserved` exists so
        # a prompt cannot fill the window; this is the other half of that promise,
        # telling the server not to generate past it.
        max_tokens => $config.budget.reserved,

        # Qwen3 reads this to decide whether to emit a reasoning block. Off by
        # default, because those tokens come out of the same window and
        # `ContextPolicy` cannot know they are coming. See `config/chatbot.toml`.
        chat_template_kwargs => %( enable_thinking => $config.sampling.thinking ),

        response_format => %(
            type => 'json_schema',
            json_schema => %(
                name   => 'response_intent',
                strict => True,
                schema => response-schema($lexicon, $morphology),
            ),
        ),
    );
}
