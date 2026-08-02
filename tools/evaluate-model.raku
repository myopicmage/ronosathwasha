#!/usr/bin/env raku

=begin pod

=head1 NAME

evaluate-model.raku - measure a local model against held-out Rono meanings

=head1 SYNOPSIS

    raku -Ilib tools/evaluate-model.raku --dry-run
    raku -Ilib tools/evaluate-model.raku
    raku -Ilib tools/evaluate-model.raku --limit=1

=head1 CONTRACT

The cases and thresholds live in C<data/model-evaluation.toml>. A case is
correct only when the local model's structured answer projects to the same
meaning as the declared expectation. Surface spelling is not scored here:
Raku owns that boundary.

=end pod

use lib $?FILE.IO.parent.parent.add('lib').Str;

use Ronosathwasha::Capabilities;
use Ronosathwasha::ChatModel;
use Ronosathwasha::Chatbot;
use Ronosathwasha::Config;
use Ronosathwasha::ConversationState;
use Ronosathwasha::Data;
use Ronosathwasha::Dialogue;
use Ronosathwasha::Intent;
use Ronosathwasha::Lexicon;
use Ronosathwasha::LlamaCpp;
use Ronosathwasha::Morphology;
use Ronosathwasha::Model;
use Ronosathwasha::ModelProtocol;
use Ronosathwasha::Projection;
use Ronosathwasha::PromptContext;
use Ronosathwasha::Script;

sub usage(--> Str) {
    q:to/USAGE/.trim;
    Evaluate the configured local model against the held-out corpus.

      raku -Ilib tools/evaluate-model.raku              run all cases
      raku -Ilib tools/evaluate-model.raku --limit=1   run a bounded smoke test
      raku -Ilib tools/evaluate-model.raku --dry-run    inspect cases and thresholds

    A full run requires llama-server and the model path from config/chatbot.toml.
    The evaluator never writes language declarations or promotes a result.
    USAGE
}

sub case-data(--> Hash) {
    my $document = read-toml(repository-root.add('data/model-evaluation.toml'));

    my %data := $document.data;
    %data;
}

sub raw-answer(%case --> Hash) {
    return %(
        kind       => %case<kind>,
        phatic_act => %case<phatic_act>,
    ) if %case<kind> eq 'phatic';

    my @arguments = %case<arguments>.List.map(-> Str:D $encoded {
        my ($role, $stem) = $encoded.split(':', 2);
        %( role => $role, stem => $stem );
    });

    my %raw = %(
        kind       => %case<kind>,
        predicate  => %case<predicate>,
        speech_act => %case<speech_act>,
        tense      => %case<tense>,
        aspect     => %case<aspect>,
        polarity   => %case<polarity>,
        modality   => %case<modality>,
        arguments  => @arguments,
    );

    for <question_scope question_kind> -> $field {
        %raw{$field} = %case{$field} if %case{$field}:exists;
    }

    %raw;
}

sub strata(%case --> List) {
    my @labels = %case<strata>.List;
    @labels.push: "response_kind:{ %case<kind> }"
        unless @labels.grep(*.starts-with('response_kind:'));
    @labels.List;
}

class RecordingInference does Inference {
    has Inference:D $.inner is required;
    has Mu $.last-answer is rw;

    method clear(--> Nil) {
        $!last-answer = Nil;
    }

    method complete(@messages) {
        my $answer = $!inner.complete(@messages);
        $!last-answer = $answer;
        $answer;
    }
}

sub safe-respond(Model:D $model, PromptContext:D $context) {
    return $model.respond($context);

    CATCH {
        default { .fail }
    }
}

sub with-raw(Str:D $status, $raw --> Str) {
    return $status unless $raw.defined;

    "$status; raw: { $raw ~~ Associative ?? $raw.raku !! $raw.^name }";
}

sub response-invariant(--> PromptInvariant) {
    PromptInvariant.new(
        :label('response schema'),
        :text(q:to/SCHEMA/.trim),
            Return exactly one JSON object. Use `kind: express` for a meaning
            the language can say, or `kind: phatic` with `phatic_act: greeting`
            for a declared social move. Use `kind: gap` when the language cannot
            carry the meaning, naming `wanted` and `missing`. The schema enforces
            the remaining fields and declared vocabulary.
            SCHEMA
    );
}

sub evaluation-context(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $prompt
    --> PromptContext
) {
    PromptContext.new(
        :schema(response-invariant()),
        :capabilities(capabilities-invariant($lexicon, $morphology)),
        :state(ConversationState.new.said(Human, $prompt)),
    );
}

sub percent(Numeric:D $rate --> Str) {
    sprintf('%.1f%%', $rate * 100);
}

sub describe-thresholds(%data --> Str) {
    "overall >= { percent(%data<minimum_overall_accuracy>) }; "
        ~ "each stratum >= { percent(%data<minimum_stratum_accuracy>) }";
}

sub dry-run(%data, @cases --> Nil) {
    say "cases: { @cases.elems }";
    say "thresholds: { describe-thresholds(%data) }";
    say "axes: { %data<required_axes>.List.join(', ') }";
    say 'diagnostics: raw model answers retained; failures preserve their cause';
    say 'model run: skipped';
}

sub evaluate(
    Config:D     $config,
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Numeric:D    $overall-threshold,
    Numeric:D    $stratum-threshold,
    @cases
    --> Int
) {
    my $inference = RecordingInference.new(
        :inner(llama-cpp($config, $lexicon, $morphology)),
    );
    my $model = chat-model(
        $config,
        $lexicon,
        $morphology,
        $inference,
    );

    say "model: { $config.model.name } { $config.model.quantisation }";
    say "weights: { $config.model.path }";
    say "context: { $config.budget.total } tokens, { $config.budget.reserved } reserved";
    say 'memory: not exposed by the configured llama-server client';

    my @results;

    for @cases -> %case {
        my $started = now;
        my $expected = intent-from($lexicon, $morphology, raw-answer(%case));

        die "evaluation case { %case<id> } has an invalid expected meaning"
            unless $expected ~~ ResponseIntent;

        $inference.clear;
        my $actual = safe-respond($model,
            evaluation-context($lexicon, $morphology, %case<prompt>),
        );
        my Numeric $seconds = now - $started;
        my Bool $correct = False;
        my Str  $status;

        if $expected ~~ Express && $actual ~~ Express {
            my $admitted = admit-intent($script, $lexicon, $morphology, $actual);

            if $admitted ~~ Str {
                my @differences = semantic-projection($lexicon, $morphology, $expected)
                    .differences(semantic-projection($lexicon, $morphology, $actual));

                $correct = @differences.elems == 0;
                $status = $correct
                    ?? 'correct'
                    !! "wrong: { @differences.join(', ') }";
            }
            else {
                $status = "inadmissible: { $admitted.summary }";
            }
        }
        elsif $expected ~~ Phatic && $actual ~~ Phatic {
            my $said = try realize-phatic($lexicon, $actual);

            if $said ~~ Str {
                $correct = $expected.act == $actual.act;
                $status = $correct
                    ?? 'correct'
                    !! 'wrong: phatic_act';
            }
            else {
                $status = "inadmissible: { $said.exception.message }";
            }
        }
        elsif $actual ~~ Gap {
            $status = "gap: { $actual.summary }";
        }
        elsif $actual ~~ Failure {
            $status = "failure: { $actual.exception.message }";
        }
        elsif !$actual.defined {
            $status = 'failure: model returned no response (Any)';
        }
        else {
            $status = "unexpected response type: { $actual.^name }";
        }

        $status = with-raw($status, $inference.last-answer)
            unless $correct;
        say "{ %case<id> }: { $status } ({ sprintf('%.3fs', $seconds) })";
        @results.push: %(
            correct => $correct,
            latency => $seconds,
            strata  => strata(%case),
        );
    }

    my Int $correct = @results.grep(*<correct>).elems;
    my Int $total   = @results.elems;
    my Numeric $overall = $correct / $total;
    my Bool $passed = $overall >= $overall-threshold;

    say "overall: { percent($overall) } ($correct/$total)";

    my %strata;
    for @results -> %result {
        for %result<strata>.List -> $label {
            %strata{$label} //= %( correct => 0, total => 0 );
            %strata{$label}<total>++;
            %strata{$label}<correct>++ if %result<correct>;
        }
    }

    for %strata.keys.sort -> $label {
        my Int $stratum-total   = %strata{$label}<total>;
        my Int $stratum-correct = %strata{$label}<correct>;
        my Numeric $rate = $stratum-correct / $stratum-total;

        say "stratum { $label }: { percent($rate) } "
            ~ "({ $stratum-correct }/{ $stratum-total })";

        $passed = False
            if $rate < $stratum-threshold;
    }

    say $passed ?? 'result: PASS' !! 'result: FAIL';
    $passed ?? 0 !! 1;
}

sub MAIN(
    Bool :$help    = False,
    Bool :$dry-run = False,
    Int  :$limit   = 0,
) {
    if $help {
        say usage;
        return;
    }

    die '--limit must be positive' if $limit < 0;

    my %data = case-data();
    my @cases = %data<case>.List;

    die "--limit cannot exceed { @cases.elems }"
        if $limit > @cases.elems;

    if $dry-run {
        dry-run(%data, @cases);
        return;
    }

    my @selected = $limit > 0 ?? @cases.head($limit) !! @cases;
    my IO::Path $root = repository-root;
    my IO::Path $data-path = $root.add('data');
    my $config = load-config($root.add('config/chatbot.toml'));
    my $script = load-script($data-path.add('script.toml'));
    my $lexicon = load-lexicon($data-path.add('lexicon.toml'));
    my $morphology = load-morphology($data-path.add('morphology.toml'));

    exit evaluate(
        $config,
        $script,
        $lexicon,
        $morphology,
        %data<minimum_overall_accuracy>,
        %data<minimum_stratum_accuracy>,
        @selected,
    );
}
