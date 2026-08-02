=begin pod

=head1 Ronosathwasha::LlamaTokenCounter

What a prompt actually costs, asked of the model that will be charged for it.

=head2 The estimate was wrong in one direction, always

C<Ronosathwasha::TokenCounter> ships two counters and says of both that they are not to
be trusted. C<PerWord> is arithmetic a test can predict. C<Approximate> is the
four-characters-per-token rule of thumb, kept because it is what people reach for and
named so that reaching for it is visible in a diff.

Neither is what the model charges, and the direction of the error is known. Two things
make it worse than a rough guess:

=item The tokenizer's merges were learned from a corpus that has never contained
C<rorothwamo>. Invented words in a mostly-Latin alphabet fragment rather than combine,
and C<ə> and C<ð> are non-ASCII on top of that. Measured against Qwen3: Ronosathwasha
runs about 2.2 characters per token (C<Lari thinəme.> is 6, C<rorothwamo> is 4) where
English runs 4.4 to 6.5 (C<understanding> is 2). So roughly two to three times the cost
per character, which is smaller than it feels and still enough to matter over a long
conversation.

This is about Rono B<in the conversation>, which is the only place it costs anything.
C<Turn.text> reaches the model verbatim, so a session conducted in Rono pays the rate
above on every turn. The schema's enumeration of every nameable stem is free:
C<response_format> is compiled to a sampling grammar server-side and never enters the
context, measured at 18 prompt tokens with and without a 91-stem enumeration. Easy to
get backwards, and it would send anyone optimizing the wrong half.

=item The template adds framing that nothing in the pure half can see. Every message
gets role markers and control tokens, once per message, so the error grows with the
length of the conversation rather than staying constant. That is the shape that
overflows a long session and never a short one. Measured: two messages cost 24 tokens
and four cost 45, against 8 words of actual content.

=head2 Two requests, because it is two questions

C<llama-server> separates them and so does this. C<apply-template> asks what the GGUF's
Jinja template makes of a message list; C<tokenize> asks how many tokens a string is.
Neither alone answers the question, which is why C<PromptTokenizer> takes a message list
where C<TokenCounter> takes a C<Str>: the first step is impossible from a string.

The cost is a round trip per measurement, and C<ContextPolicy> measures once per folding
attempt. Its pod already says so and says the fix is caching a count per turn rather
than a cleverer search. That is not built, because nothing has profiled it and a long
conversation on a local server is a few milliseconds either way.

=head2 It also satisfies the flat counter seam

C<ContextPolicy> currently receives the older C<TokenCounter> shape and measures the
plain C<PromptContext.render> form. C<count-prompt> remains the exact message-list
surface for callers that have the model template available; C<count> is the compatible
flat-text surface used by the existing policy. Keeping both on one object lets the live
interface use the real tokenizer without replacing the deterministic test counter.

=head2 It shares C<LlamaCpp>'s transport, deliberately

Same role, same fake in tests, same single place where a socket exists. A counter that
opened its own connection would be a second thing to configure, a second timeout to get
wrong, and a second seam a contract test has to know about.

=head2 And the seam has a cost, paid once here

Every test of this module and of C<LlamaCpp> injects a fake, which is the right trade for
the reasons that module's pod gives. The consequence is that C<HttpTransport> itself was
never executed by anything, and it was broken: a bare final expression in front of a
C<CATCH> is sunk, so C<post> returned C<Any> and the first live call died on
C<No such method 'status'> with a green suite behind it.

A fake cannot find that. So a run against a real C<llama-server> is part of finishing
this, not an optional extra: the numbers quoted above are from that run, and so is the
knowledge that the stack works end to end.

=end pod

unit module Ronosathwasha::LlamaTokenCounter;

use JSON::Fast;

use X::Ronosathwasha;

use Ronosathwasha::Config;
use Ronosathwasha::LlamaCpp;
use Ronosathwasha::ModelProtocol;
use Ronosathwasha::TokenCounter;

#| The real cost of a prompt, from the model that will charge it.
class LlamaTokenCounter does PromptTokenizer does TokenCounter is export {
    has Config:D    $.config    is required;
    has Transport:D $.transport is required;

    #| How many tokens the templated message list comes to.
    #|
    #| No return type declared, so a server that is not running stays an inert
    #| `Failure` rather than throwing; see `Ronosathwasha::Types`. A budget that cannot
    #| be measured is a condition a caller may want to report rather than one that
    #| should abort.
    method count-prompt(@messages) {
        my Str $templated = self!apply-template(@messages);

        return self!tokenize($templated);

        CATCH { default { .fail } }
    }

    #| Count the flat prompt form expected by `ContextPolicy`.
    #|
    #| The exact message-list route remains `count-prompt`; this method is the
    #| compatibility surface for the policy's current `TokenCounter` contract.
    method count(Str:D $text --> Int) {
        self!tokenize($text);
    }

    #| What the GGUF's own template makes of these messages.
    method !apply-template(@messages --> Str) {
        my Str $url = $!config.server.apply-template;
        my %answer  = self!ask($url, %( messages => @messages.List ));

        my $prompt = %answer<prompt>;

        die X::Ronosathwasha::Request::Malformed.new(
            :$url, :reason('no prompt in the apply-template response'),
        ) without $prompt;

        ~$prompt;
    }

    #| How many tokens that string is.
    method !tokenize(Str:D $text --> Int) {
        my Str $url = $!config.server.tokenize;

        # `add_special` on, because a real request is charged for whatever the tokenizer
        # prepends. For Qwen3 that is nothing: measured both ways against the live
        # server and got 24 either time, because the model has no BOS token. It stays on
        # so that a model which does have one is counted correctly rather than silently
        # under-counted by a constant.
        #
        # What does the real work here is that the server parses special tokens in the
        # text by default, so the `<|im_start|>` the template emitted counts as one token
        # (151644) rather than as its six characters.
        my %answer = self!ask($url, %( content => $text, add_special => True ));

        my $tokens = %answer<tokens>;

        die X::Ronosathwasha::Request::Malformed.new(
            :$url, :reason('no tokens in the tokenize response'),
        ) unless $tokens ~~ Positional;

        $tokens.elems;
    }

    #| One POST and one decode, with the failures named against the route.
    method !ask(Str:D $url, %payload --> Hash) {
        my $reply = $!transport.post($url, to-json(%payload));

        die X::Ronosathwasha::Request::Refused.new(
            :$url, :status($reply.status), :body($reply.body),
        ) unless $reply.status == 200;

        my $parsed = from-json($reply.body);

        die X::Ronosathwasha::Request::Malformed.new(
            :$url, :reason('the response was not a JSON object'),
        ) unless $parsed ~~ Associative;

        return $parsed;

        CATCH {
            # Not a `default` that swallows: the two `die`s above are already ours and
            # rethrowing them through a JSON-flavoured message would rename the fault.
            when X::Ronosathwasha::Request { .rethrow }

            default {
                die X::Ronosathwasha::Request::Malformed.new(
                    :$url, :reason("the response did not parse: { .message.lines.head // ~$_ }"),
                );
            }
        }
    }
}

#| The ordinary way to build one: real transport, timeout from the configuration.
sub llama-token-counter(Config:D $config --> LlamaTokenCounter) is export {
    LlamaTokenCounter.new(
        :$config,
        :transport(HttpTransport.new(:timeout-seconds($config.server.timeout-seconds))),
    );
}
