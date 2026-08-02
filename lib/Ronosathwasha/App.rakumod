=begin pod

=head1 Ronosathwasha::App

The composition root for one local chatbot session.

The language modules are deliberately usable without this file. C<App> is where
the machine-specific configuration, local inference transport, tokenizer,
prompt invariants, terminal and durable session log are assembled. Tests can
still inject a deterministic C<Model> and C<TokenCounter>, so constructing the
composition does not require a running server or model weights.

Persistence is connected through C<Terminal>'s observer seams rather than by
duplicating its loop. The terminal remains a conversation shell; this module
decides what survives the process.

=end pod

unit module Ronosathwasha::App;

use Ronosathwasha::Capabilities;
use Ronosathwasha::ChatModel;
use Ronosathwasha::Chatbot;
use Ronosathwasha::Config;
use Ronosathwasha::ConversationState;
use Ronosathwasha::Dialogue;
use Ronosathwasha::LanguageEvidence;
use Ronosathwasha::LlamaCpp;
use Ronosathwasha::LlamaTokenCounter;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Model;
use Ronosathwasha::Morphology;
use Ronosathwasha::PromptContext;
use Ronosathwasha::Script;
use Ronosathwasha::SessionLog;
use Ronosathwasha::Terminal;
use Ronosathwasha::TokenCounter;

#| The fully assembled local application. The fields are dependencies rather
#| than hidden globals, which is what lets tests replace the model and counter.
class App is export {
    has Config:D        $.config     is required;
    has Script:D        $.script     is required;
    has Lexicon:D       $.lexicon    is required;
    has Morphology:D    $.morphology is required;
    has Model:D         $.model      is required;
    has PromptContext:D $.context    is required;
    has TokenCounter:D  $.counter    is required;
    has SessionLog:D    $.log        is required;

    has IO::Handle:D $.input  = $*IN;
    has IO::Handle:D $.output = $*OUT;

    #| Run one terminal session and retain its machine-readable observations.
    method run(--> LanguageEvidence:D) {
        $!log.append(
            'session-started',
            model            => $!config.model.name,
            quantisation     => $!config.model.quantisation,
            context_total    => $!config.budget.total,
            context_reserved => $!config.budget.reserved,
        );

        my LanguageEvidence:D $evidence = self!terminal.run;

        $!log.append('session-ended', findings => $evidence.elems);
        $evidence
    }

    #| Copy the durable stream for author review without exposing the log's
    #| representation to callers that only need the application shell.
    method export(IO::Path:D $destination --> IO::Path:D) {
        $!log.export($destination)
    }

    method !terminal(--> Terminal:D) {
        Terminal.new(
            :$!script,
            :$!lexicon,
            :$!morphology,
            :$!model,
            :context($!context),
            :budget($!config.budget),
            :counter($!counter),
            :$!input,
            :$!output,
            :on-exchange(-> Exchange:D $exchange {
                $!log.record-exchange($exchange);
            }),
            :on-evidence(-> LanguageEvidence:D $evidence {
                $!log.record-evidence($evidence);
            }),
            :on-export(-> IO::Path:D $destination --> IO::Path:D {
                $!log.export($destination);
            }),
        );
    }
}

#| Build the production application from the repository's declarations and
#| machine configuration. The local model server remains a separately managed
#| process, as required by C<CHATBOT.md>.
sub load-app(
    IO::Path:D $root,
    IO::Path:D $session-path,
    IO::Handle:D :$input = $*IN,
    IO::Handle:D :$output = $*OUT,
    --> App:D
) is export {
    my IO::Path $data = $root.add('data');

    my $config     = load-config($root.add('config/chatbot.toml'));
    my $script     = load-script($data.add('script.toml'));
    my $lexicon    = load-lexicon($data.add('lexicon.toml'));
    my $morphology = load-morphology($data.add('morphology.toml'));
    my $log        = session-log($session-path);

    my PromptContext:D $context = PromptContext.new(
        :schema(PromptInvariant.new(
            :label('response schema'),
            :text(q:to/SCHEMA/.trim),
                Return exactly one JSON object. Use `kind: express` for a meaning
                the language can say, or `kind: phatic` with `phatic_act: greeting`
                for a greeting. Use `kind: gap` when it cannot, naming `wanted` and
                `missing`. The schema enforces the remaining fields and declared
                vocabulary.
                SCHEMA
        )),
        :capabilities(capabilities-invariant($lexicon, $morphology)),
        :state(ConversationState.new),
    );

    my $inference = llama-cpp($config, $lexicon, $morphology);
    my $model     = chat-model($config, $lexicon, $morphology, $inference);
    my $counter   = llama-token-counter($config);

    App.new(
        :$config,
        :$script,
        :$lexicon,
        :$morphology,
        :$model,
        :$context,
        :budget($config.budget),
        :$counter,
        :$log,
        :$input,
        :$output,
    );
}
