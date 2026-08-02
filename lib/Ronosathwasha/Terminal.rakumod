=begin pod

=head1 Ronosathwasha::Terminal

The imperative shell around one conversation.

The language and model stay behind C<Dialogue.take-turn>. This module owns the
things a terminal actually has to own: reading lines, keeping the newest fitted
context, displaying an exchange, and retaining language evidence before the
conversation is folded.

Input and output are handles rather than globals in the implementation, so the
same loop can be driven by a person or by a focused test. C</quit> exits without
creating a turn, and C</evidence> reports the durable findings without sending a
message to the model.

=end pod

unit module Ronosathwasha::Terminal;

use Ronosathwasha::Actions;
use Ronosathwasha::ConversationState;
use Ronosathwasha::Dialogue;
use Ronosathwasha::Intent;
use Ronosathwasha::LanguageEvidence;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Model;
use Ronosathwasha::Morphology;
use Ronosathwasha::PromptContext;
use Ronosathwasha::Script;
use Ronosathwasha::TokenCounter;

#| A terminal session with all of the pure machinery injected.
class Terminal is export {
    has Script:D        $.script     is required;
    has Lexicon:D       $.lexicon    is required;
    has Morphology:D    $.morphology is required;
    has Model:D         $.model      is required;
    has PromptContext:D $.context    is required;
    has Budget:D        $.budget     is required;
    has TokenCounter:D  $.counter    is required;

    has IO::Handle:D $.input  = $*IN;
    has IO::Handle:D $.output = $*OUT;

    has Str:D $.input-prompt = 'you> ';
    has Str:D $.bot-prompt   = 'laari> ';

    #| Optional observers let an outer shell retain durable records without
    #| making the terminal responsible for a storage format. They are called
    #| only after the turn has become an `Exchange` or updated evidence.
    has Callable $.on-exchange;
    has Callable $.on-evidence;

    #| Run until EOF, `/quit`, or an infrastructure/model failure. The evidence
    #| value is separate from the rolling context because folding is allowed to
    #| forget turns but never gets to erase a finding.
    method run(--> LanguageEvidence) {
        my PromptContext  $context = $!context;
        my LanguageEvidence $evidence = LanguageEvidence.new;

        loop {
            $!output.print($!input-prompt);
            $!output.flush;

            my $line = $!input.get;
            last unless $line.defined;

            my Str $heard = $line.trim;

            next unless $heard.chars;
            last if $heard eq '/quit';

            if $heard eq '/evidence' {
                $!output.say("{ $!bot-prompt }[evidence]");
                $!output.say($evidence.report);
                next;
            }

            my $result = take-turn(
                $!script, $!lexicon, $!morphology, $!model, $context,
                $!budget, $!counter, $heard,
            );

            unless $result.defined {
                $!output.say("{ $!bot-prompt }[error] { $result.exception.message }");
                last;
            }

            my Exchange $exchange = $result;
            $context = $exchange.context;
            $!on-exchange($exchange) if $!on-exchange.defined;
            $evidence = self!record($exchange, $evidence);
            $!on-evidence($evidence) if $!on-evidence.defined;
            self!display($exchange);
        }

        $evidence;
    }

    #| Harvest only the findings the evidence queue is designed to hold. An
    #| inadmissible model answer is a grammar collision, not a language gap, so
    #| `Dialogue` keeps it visible without sending it here.
    method !record(
        Exchange:D        $exchange,
        LanguageEvidence:D $evidence
        --> LanguageEvidence
    ) {
        my LanguageEvidence $next = $evidence;

        $next = $next.note($exchange.intent)
            if $exchange.intent ~~ Gap;

        $next = $next.note($exchange.understanding.because)
            if $exchange.understanding ~~ NotUnderstood;

        $next;
    }

    #| Keep the terminal vocabulary small and make the distinction between an
    #| unreadable human turn, a gap, and an inadmissible model answer visible.
    method !display(Exchange:D $exchange) {
        $!output.say("{ $!bot-prompt }[input] { $exchange.understanding.summary }")
            unless $exchange.understood;

        if $exchange.said.defined {
            $!output.say("{ $!bot-prompt }{ $exchange.said }");
        }
        elsif $exchange.inadmissible.defined {
            $!output.say("{ $!bot-prompt }[inadmissible] { $exchange.inadmissible.summary }");
        }
        elsif $exchange.intent ~~ Gap {
            $!output.say("{ $!bot-prompt }[gap] { $exchange.intent.summary }");
        }
    }
}
