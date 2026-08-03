=begin pod

=head1 Ronosathwasha::LlamaCpp

Inference against a local C<llama-server>, over an injectable transport.

=head2 Why the socket is behind a role

A contract test has to assert the exact request this application sends, and there are
two ways to do that. Bind a port, run a stub server, and read what arrives. Or put the
transport behind a role, hand the client a fake, and read what it was given.

The second is taken, and the reason is not effort. A port in a test suite is a flake
waiting for a busy machine: it needs a free number, a listener that starts before the
request and outlives it, and a teardown that runs even when an assertion throws. None
of that tests anything about this application.

What a stub server would verify beyond this is the bytes on the wire, and the fake sees
those too: it is handed the encoded JSON body and the URL, so a contract test asserts
the same string a socket would have carried. What it cannot check is that
C<HTTP::Tiny> forms a valid HTTP request, which is C<HTTP::Tiny>'s test suite's job.

=head2 The answer arrives twice-wrapped

The OpenAI-compatible route returns an envelope, and the model's actual answer is a
string inside it:

    { "choices": [ { "message": { "content": "{\"kind\":\"gap\", ...}" } } ] }

So C<complete> decodes twice: once for the envelope, once for the content, because the
schema constrained the content to be JSON and the protocol still delivers it as text.
Both decodes can fail and they fail differently, which is why
C<X::Ronosathwasha::Request::Malformed> carries a reason rather than a boolean.

=head2 What this refuses to do

It does not validate the answer. C<intent-from> does that, and keeping them apart is
what makes "the server said something odd" a different error from "the model named a
word that does not exist". Conflating them would send somebody looking in the lexicon
for a transport bug.

It does not start C<llama-server>. A chatbot that spawns its own inference server owns
a process lifecycle nobody asked it to own, and "connection refused" is a better
failure than a half-started child holding ten gigabytes.

=end pod

unit module Ronosathwasha::LlamaCpp;

use JSON::Fast;
use HTTP::Tiny;

use X::Ronosathwasha;

use Ronosathwasha::Config;
use Ronosathwasha::Lexicon;
use Ronosathwasha::ModelProtocol;
use Ronosathwasha::Morphology;

#| What the server said, before anybody decides whether it makes sense.
class Reply is export {
    has Int:D $.status is required;
    has Str:D $.body   is required;
}

#| One POST. The seam a contract test replaces.
role Transport is export {
    method post(Str:D $url, Str:D $body --> Reply) { ... }
}

#| The real one.
class HttpTransport does Transport is export {
    has Int:D $.timeout-seconds is required;

    method post(Str:D $url, Str:D $body --> Reply) {
        my %response = HTTP::Tiny.new(:timeout($!timeout-seconds)).post:
            $url,
            content => $body,
            headers => %( 'content-type' => 'application/json' );

        # `return`, not a bare expression. Third time: a final expression in front of a
        # `CATCH` is sunk, so this handed back `Any` and the caller died on
        # `No such method 'status'`. Nothing caught it, because every test in the suite
        # injects a fake transport and this method had therefore never once run.
        # That is the cost of the seam, and it is why stop 9 ends with a live probe
        # rather than a green suite.
        return Reply.new(
            :status(%response<status>.Int),

            # `.decode` rather than `~`, because the body arrives as a Blob and
            # stringifying a Blob gives its gist rather than its contents, which
            # produces a JSON parse error naming bytes nobody wrote.
            :body(%response<content> ~~ Blob ?? %response<content>.decode !! ~(%response<content> // '')),
        );

        CATCH {
            default {
                # A refused connection and a DNS failure and a timeout are one thing
                # to a caller: nobody answered. The reason is kept because it is the
                # difference between starting the server and fixing the config.
                die X::Ronosathwasha::Request::Unreachable.new(
                    :$url, :reason(.message.lines.head // ~$_),
                );
            }
        }
    }
}

#| A model, reached over HTTP.
class LlamaCpp does Inference is export {
    has Config:D     $.config     is required;
    has Lexicon:D    $.lexicon    is required;
    has Morphology:D $.morphology is required;
    has Transport:D  $.transport  is required;

    #| Ask, and return the raw answer for `intent-from` to judge.
    #|
    #| No return type declared, so a refusal stays an inert `Failure`; see
    #| `Ronosathwasha::Types`. A server that is not running is an ordinary condition
    #| on a machine where it is started by hand.
    method complete(@messages) {
        my Str $url  = $!config.server.completions;

        # Stable bytes are part of deterministic inference. Raku hashes deliberately
        # vary their iteration order between processes, and llama.cpp compiles the
        # response schema into a token grammar in the order it receives. Without
        # canonical keys, two equal schemas can therefore guide generation through
        # different field orders.
        my Str $body = to-json(
            request-body($!config, $!lexicon, $!morphology, @messages),
            :sorted-keys,
        );

        my $reply = $!transport.post($url, $body);

        die X::Ronosathwasha::Request::Refused.new(
            :$url, :status($reply.status), :body($reply.body),
        ) unless $reply.status == 200;

        my %envelope := self!decode($url, $reply.body, 'the response envelope');

        my $content = %envelope<choices>[0]<message><content>;

        die X::Ronosathwasha::Request::Malformed.new(
            :$url, :reason('no choices[0].message.content in the response'),
        ) without $content;

        # The second decode. The schema constrained the content to be JSON and the
        # protocol still hands it over as a string.
        # `return`, because the `CATCH` below is the last statement of the method and a
        # bare final expression is sunk in front of it, so this returned `Nil` and the
        # symptom was a type check about `Associative` two frames away. `Dialogue`
        # carries the same note; this is the second time it has been earned.
        return self!decode($url, ~$content, 'the schema-constrained content');

        CATCH { default { .fail } }
    }

    method !decode(Str:D $url, Str:D $text, Str:D $what) {
        my $parsed = from-json($text);

        die X::Ronosathwasha::Request::Malformed.new(
            :$url, :reason("$what was not a JSON object"),
        ) unless $parsed ~~ Associative;

        return $parsed;

        CATCH {
            default {
                # Re-raised as ours rather than passed through, because a JSON
                # parser's message names a character offset in a string the caller
                # never saw and says nothing about which of the two decodes failed.
                die X::Ronosathwasha::Request::Malformed.new(
                    :$url, :reason("$what did not parse: { .message.lines.head // ~$_ }"),
                );
            }
        }
    }
}

#| The ordinary way to build one: real transport, timeout from the configuration.
sub llama-cpp(Config:D $config, Lexicon:D $lexicon, Morphology:D $morphology --> LlamaCpp) is export {
    LlamaCpp.new(
        :$config, :$lexicon, :$morphology,
        :transport(HttpTransport.new(:timeout-seconds($config.server.timeout-seconds))),
    );
}
