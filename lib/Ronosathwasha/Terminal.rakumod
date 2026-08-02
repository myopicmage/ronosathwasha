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
use Ronosathwasha::ContextPolicy;
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
    has Callable $.on-export;

    #| Run until EOF, `/quit`, or an infrastructure/model failure. The evidence
    #| value is separate from the rolling context because folding is allowed to
    #| forget turns but never gets to erase a finding.
    method run(--> LanguageEvidence) {
        my PromptContext  $context = $!context;
        my LanguageEvidence $evidence = LanguageEvidence.new;
        my Exchange $last-exchange;

        loop {
            $!output.print($!input-prompt);
            $!output.flush;

            my $line = $!input.get;
            last unless $line.defined;

            my Str $heard = $line.trim;

            next unless $heard.chars;
            last if $heard eq '/quit';

            if $heard eq '/evidence' {
                self!display-evidence($evidence, 'evidence');
                next;
            }

            if $heard eq '/gaps' {
                self!display-evidence($evidence, 'gaps');
                next;
            }

            if $heard eq '/budget' {
                self!display-budget($context);
                next;
            }

            if $heard eq '/parse' {
                self!display-parse($last-exchange);
                next;
            }

            if $heard eq '/export' || $heard.starts-with('/export ') {
                self!export($heard);
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
            $last-exchange = $exchange;
            $context = $exchange.context;
            $!on-exchange($exchange) if $!on-exchange.defined;
            $evidence = self!record($exchange, $evidence);
            $!on-evidence($evidence) if $!on-evidence.defined;
            self!display($exchange);
        }

        $evidence;
    }

    method !display-evidence(LanguageEvidence:D $evidence, Str:D $label) {
        $!output.say("{ $!bot-prompt }[{ $label }]");
        $!output.say($evidence.report);
    }

    #| The count uses the same counter and budget as the turn policy. It is an
    #| operational view, not a second estimate hidden in the interface.
    method !display-budget(PromptContext:D $context) {
        my $cost = try context-cost($context, $!counter);

        unless $cost.defined {
            $!output.say("{ $!bot-prompt }[budget] unavailable: { $cost.self.exception.message }");
            return;
        }

        my Str $fit = $!budget.fits($cost)
            ?? 'fits'
            !! "over by { $!budget.overflow($cost) }";

        $!output.say(
            "{ $!bot-prompt }[budget] cost { $cost }, available { $!budget.available }"
                ~ " (window { $!budget.total }, reserved { $!budget.reserved }, "
                ~ "{ $context.depth } live turns, { $fit })",
        );
    }

    method !display-parse(Exchange $exchange) {
        my Str $summary = $exchange.defined
            ?? $exchange.summary
            !! 'no turn has been parsed yet';

        $!output.say("{ $!bot-prompt }[parse] { $summary }");
    }

    method !export(Str:D $command) {
        my Str $raw-path = $command.substr('/export'.chars).trim;

        unless $raw-path.chars {
            $!output.say("{ $!bot-prompt }[export] usage: /export PATH");
            return;
        }

        unless $!on-export.defined {
            $!output.say("{ $!bot-prompt }[export] unavailable");
            return;
        }

        my $destination = $raw-path.IO;
        my $result = try $!on-export($destination);

        if $result.defined {
            $!output.say("{ $!bot-prompt }[export] wrote { $result }");
        }
        else {
            $!output.say(
                "{ $!bot-prompt }[export] failed: { $result.self.exception.message }",
            );
        }
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
