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
the roots C<predicate-roots> reports, and the argument stems enumerate
C<participant-stems> separately. B<A model cannot name a word the language does not
have, because the decoder will not emit the tokens.> The two sets differ by review
C<027>'s finding: a predicate must be a root the realizer can inflect, so the bound
infinitive forms are out, while a participant must be a word that can stand as a
constituent, so the infinitives are in and the bare roots are out.

C<intent-from> checks the same thing again afterwards, and that is deliberate rather
than redundant. Plan C<014> asks for it in those words: reject unknown fields or
invalid combinations even when the server claims schema success. A constrained decoder
can guarantee the shape of JSON and cannot guarantee that a server honoured the
constraint, that a future server will, or that the combination of two individually
legal fields means anything.

C<additionalProperties> is false, which is the same refusal at the schema level: a
field nobody asked for is a model answering a different question.

=head2 A tagged union, because the fields are not independent

An C<express> needs a predicate and four features; a C<gap> needs two strings and would
be impossible to express if the schema demanded a predicate. One flat object cannot say
that, so it used to require only C<kind> and leave the rest optional. The consequence
showed up on the first live run: the model answered with three fields, omitted C<tense>,
C<aspect>, C<polarity>, C<modality> and C<speech_act>, and the constrained decoder was
perfectly happy because nothing had been required.

C<oneOf> with C<const> on the tag is the standard way to say it, and it is checked rather
than assumed: llama.cpp compiles both into grammar alternation, and a model instructed in
as many words to emit only C<{"kind": "express"}> cannot, because no path through the
grammar closes the object early. B<The omission stops being something to reject and
becomes something the decoder cannot produce.>

The three fields that stay optional each have a real default that C<intent-from> applies:
C<arguments> to C<[]>, C<nominal_predicate> to C<False>, C<tense> to a timeless identity.

=head2 What the schema still cannot express, and who catches it

An absent tense is legal only on a nominal predicate, because a verb without a tense
morpheme is not a word. That is a constraint over I<which stem was chosen>, so expressing
it in the grammar would mean splitting the predicate enumeration into verbal and nominal
halves and doubling the branches. C<if>/C<then> would say it directly and is the one part
of JSON Schema llama.cpp's conversion does not handle.

So the pairing stays with C<intent-from>, which refuses it with a message naming it. This
is the place that cannot be silently unsupported.

C<question_scope> is the same shape a second time: legal exactly when C<speech_act> is
C<interrogative>, which is a constraint I<between> fields and therefore C<if>/C<then>
again. The wire leaves it optional and C<Semantics::Asks> refuses the mismatch, in the
role all three meaning types compose, so the model's copy of the rule and the corpus's
copy cannot be two rules.

=head2 The vocabulary is free, and the conversation is not

Worth knowing before optimizing the wrong half: the enumeration of stems costs B<zero>
prompt tokens. C<response_format> is compiled to a sampling grammar server-side and never
enters the context. Measured: the same request with and without a 91-stem enumeration
reports 18 prompt tokens either way.

What does cost tokens is Rono in the conversation itself, because C<Turn.text> reaches the
model verbatim. See C<Ronosathwasha::LlamaTokenCounter>.

=end pod

unit module Ronosathwasha::ModelProtocol;

use X::Ronosathwasha;

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
#| Built from `answer-vocabulary`, `predicate-roots` and `participant-stems`
#| rather than written out, so the strings the decoder accepts and the strings
#| the schema permits cannot drift apart.
#| The `express` branch: a thing to say, with everything `intent-from` will demand.
#|
#| The required list is not a judgement call. `intent-from` runs `speech_act`, `aspect`,
#| `polarity` and `modality` through `pick`, which looks the value up in a table and
#| dies when it is absent, because `%table{''}` is undefined. It checks `predicate`
#| against `predicate-roots`. So these six are exactly the fields whose absence is
#| already fatal one layer up, moved to where the decoder can prevent it instead.
sub express-branch(@predicates, @stems, %v --> Hash) {
    %(
        type => 'object',
        additionalProperties => False,
        required => <kind predicate speech_act aspect polarity modality>.List,

        properties => %(
            # `const`, not an enumeration of one. This is the tag that makes the union
            # discriminated: the grammar can only reach this branch's fields after
            # emitting this exact value, so a `gap`-shaped answer cannot borrow them.
            kind => %( const => 'express' ),

            # An enumeration and not a string. This is the line that makes an
            # invented word unsayable rather than merely rejected. Roots only:
            # a finished infinitive here would be inflected into a different
            # meaning, which is 027's `miriswe` walk-through.
            predicate  => enumerated(@predicates),

            speech_act => enumerated(%v<speech_act>),
            aspect     => enumerated(%v<aspect>),
            polarity   => enumerated(%v<polarity>),
            modality   => enumerated(%v<modality>),

            # Optional for the same reason `tense` is: absence is a meaning, not an
            # omission. A declarative questions nothing, so it sends no scope, and
            # "required iff interrogative" is an `if`/`then` the grammar cannot hold;
            # see the pod. The pairing is refused by `Asks` when the intent is built.
            question_scope => enumerated(%v<question_scope>),

            # The three optional ones, each because it has a real default rather than
            # because nobody got round to requiring it.
            #
            # `tense` absent is a timeless identity, which decision 22 made a meaning
            # rather than an omission, and the pairing rule stays out; see the pod.
            tense => enumerated(%v<tense>),

            # `intent-from` reads this as `False` when absent.
            nominal_predicate => %( type => 'boolean' ),

            # And this as `[]`, so a predicate with no arguments needs no key.
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
        ),
    );
}

#| The `gap` branch: the language cannot say it, and here is what is missing.
#|
#| Both fields required, matching `intent-from`, which refuses a gap without either.
#| Free text, and the only free text in the schema: a gap is the model telling Kevin
#| something the declarations cannot express, so constraining it to declared
#| vocabulary would make it unable to say what is absent.
sub gap-branch(--> Hash) {
    %(
        type => 'object',
        additionalProperties => False,
        required => <kind wanted missing>.List,

        properties => %(
            kind    => %( const => 'gap' ),
            wanted  => %( type => 'string' ),
            missing => %( type => 'string' ),
        ),
    );
}

sub response-schema(Lexicon:D $lexicon, Morphology:D $morphology --> Hash) is export {
    my %v = answer-vocabulary();
    my @predicates = predicate-roots($lexicon, $morphology).keys.sort;
    my @stems      = participant-stems($lexicon, $morphology).keys.sort;

    my %branches =
        express => express-branch(@predicates, @stems, %v),
        gap     => gap-branch();

    # Driven off the vocabulary rather than written out, so a third kind added to
    # `answer-vocabulary` without a branch here is a loud failure instead of an
    # alternative the grammar silently lacks. The old flat schema got this for free by
    # enumerating `%v<kind>` in one place; a union has to earn it.
    my @missing = %v<kind>.grep({ not %branches{$_}:exists });

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason("no schema branch for kind { @missing.join(', ') }"),
    ) if @missing;

    # A tagged union, not one object with everything optional. Each branch pins `kind`
    # with `const` and carries its own `required`, which is the standard JSON Schema
    # way to say "these fields go together" without `if`/`then`.
    #
    # Verified against the real decoder rather than assumed: llama.cpp compiles `oneOf`
    # and `const` into grammar alternation, and a model told in as many words to emit
    # only `{"kind": "express"}` still could not, because the grammar has no path that
    # closes the object early. That is the property this buys.
    %( oneOf => %v<kind>.map({ %branches{$_} }).List );
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
