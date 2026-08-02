=begin pod

=head1 Ronosathwasha::ChatModel

The semantic model at the edge of the conversation.

C<Ronosathwasha::LlamaCpp> deliberately stops at raw JSON. This module supplies
the other half of the seam: it turns a fitted C<PromptContext> into wire
messages, asks an inference implementation for its raw answer, and lets
C<intent-from> admit or refuse that answer.

The split keeps transport and language validation independent. A fake inference
implementation can exercise the same semantic path as C<llama-server>, while
the terminal interface only has to depend on C<Model>.

=end pod

unit module Ronosathwasha::ChatModel;

use Ronosathwasha::Config;
use Ronosathwasha::Intent;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Model;
use Ronosathwasha::ModelProtocol;
use Ronosathwasha::Morphology;
use Ronosathwasha::Prompt;
use Ronosathwasha::PromptContext;

#| The semantic adapter between the raw inference protocol and the dialogue loop.
class ChatModel does Model is export {
    has Config:D     $.config     is required;
    has Lexicon:D    $.lexicon    is required;
    has Morphology:D $.morphology is required;
    has Inference:D  $.inference  is required;

    #| Ask for a meaning, not a sentence. `intent-from` is the one place that
    #| decides whether the model's JSON names a meaning the declarations admit.
    method respond(PromptContext:D $context --> ResponseIntent) {
        my @messages = wire-messages($!config, $context);
        my %raw      = $!inference.complete(@messages);

        return intent-from($!lexicon, $!morphology, %raw);
    }
}

#| Build the adapter around any inference implementation. Keeping construction
#| injectable is what lets the terminal loop use the real HTTP client while its
#| tests use a recorder with no server.
sub chat-model(
    Config:D     $config,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Inference:D  $inference
    --> ChatModel
) is export {
    ChatModel.new(:$config, :$lexicon, :$morphology, :$inference);
}
