#!/usr/bin/env raku

=begin pod

=head1 NAME

chatbot.raku - start the local Ronosathwasha conversation

=head1 SYNOPSIS

    make chat
    raku scripts/chatbot.raku --help

=head1 PREREQUISITES

C<llama-server> must already be running at the URL in
C<config/chatbot.toml>. The model weights stay outside this repository and are
checked when the configuration loads.

=end pod

use lib $?FILE.IO.parent.parent.add('lib').Str;

use Ronosathwasha::Capabilities;
use Ronosathwasha::ChatModel;
use Ronosathwasha::Chatbot;
use Ronosathwasha::Config;
use Ronosathwasha::ConversationState;
use Ronosathwasha::LlamaCpp;
use Ronosathwasha::LlamaTokenCounter;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::PromptContext;
use Ronosathwasha::Script;
use Ronosathwasha::Terminal;

sub usage(--> Str) {
    q:to/USAGE/.trim;
    Ronosathwasha local conversation

      make chat       start Lauri's terminal conversation
      /evidence       show durable language findings
      /quit           leave without creating another turn

    The command expects llama-server at the configured URL. It does not start
    the server or copy model weights into the repository.
    USAGE
}

sub MAIN(Bool :$help = False) {
    if $help {
        say usage;
        return;
    }

    my IO::Path $root = repository-root;
    my IO::Path $data = $root.add('data');

    my $config     = load-config($root.add('config/chatbot.toml'));
    my $script     = load-script($data.add('script.toml'));
    my $lexicon    = load-lexicon($data.add('lexicon.toml'));
    my $morphology = load-morphology($data.add('morphology.toml'));

    my PromptContext $context = PromptContext.new(
        :schema(PromptInvariant.new(
            :label('response schema'),
            :text(q:to/SCHEMA/.trim),
                Return exactly one JSON object. Use `kind: express` for a meaning
                the language can say. Use `kind: gap` when it cannot, naming
                `wanted` and `missing`. The schema enforces the remaining fields
                and declared vocabulary.
                SCHEMA
        )),
        :capabilities(capabilities-invariant($lexicon, $morphology)),
        :state(ConversationState.new),
    );

    my $inference = llama-cpp($config, $lexicon, $morphology);
    my $model     = chat-model($config, $lexicon, $morphology, $inference);
    my $counter   = llama-token-counter($config);

    Terminal.new(
        :$script,
        :$lexicon,
        :$morphology,
        :$model,
        :$context,
        :budget($config.budget),
        :counter($counter),
    ).run;
}
