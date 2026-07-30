=begin pod

=head1 Ronosathwasha::Config

C<config/chatbot.toml>, as typed values.

=head2 Configuration is not a declaration

C<data/> holds what is true about the language and this holds what is true about this
machine. They load through the same C<Ronosathwasha::Data> helpers and they are not
the same kind of thing: a declaration is the subject of the project and a
configuration is the apparatus. Mixing them would mean a change of port number
looking like a change to the language.

=head2 Every value is checked here, at the boundary

A configuration file is untyped text and the failures it can cause are all
downstream and disguised. A budget whose reservation exceeds its total produces a
prompt that never fits. A missing model file produces a connection that succeeds and
then a server that exits. A temperature of C<"0.7"> as a string produces a request the
server rejects for reasons about JSON.

So this parses rather than validates: what leaves here is a C<Config> whose
C<Budget> has already been constructed and whose model path has already been resolved
to something that exists. There is no way to hold a configuration that has not been
checked, because the only way to get one is through the loader.

=head2 The home directory is expanded here and nowhere else

TOML has no notion of C<~>. Storing an absolute path instead would be wrong on
Kevin's other machines, and expanding it at each use would put the same three lines
in the protocol client, the tokenizer and any script that wants to check the file is
there.

=end pod

unit module Ronosathwasha::Config;

use X::Ronosathwasha;

use Ronosathwasha::Data;
use Ronosathwasha::TokenCounter;

#| Which model, and where it is.
class ModelFile is export {
    has Str      $.name          is required;
    has Str      $.quantisation  is required;
    has IO::Path $.path          is required;

    method gist(--> Str) { "$!name $!quantisation at $!path" }
}

#| Where inference lives and how long to wait for it.
class Server is export {
    has Str $.url             is required;
    has Int $.timeout-seconds is required;

    #| The chat-completions route, which is the only one inference uses.
    method completions(--> Str) { $!url.chomp('/') ~ '/v1/chat/completions' }

    #| The tokenizer route, which is how the budget learns what the model counts.
    method tokenize(--> Str) { $!url.chomp('/') ~ '/tokenize' }
}

#| What the sampler is told, and whether the model is allowed to think first.
class Sampling is export {
    has Numeric $.temperature is required;
    has Numeric $.top-p       is required;
    has Int     $.top-k       is required;
    has Bool    $.thinking    is required;
}

class Config is export {
    has ModelFile $.model    is required;
    has Budget    $.budget   is required;
    has Server    $.server   is required;
    has Sampling  $.sampling is required;
}

#| Read a value of an expected type, or fail against the file it came from.
#|
#| One sub rather than a check at each site, because the interesting part of the
#| message is which file and which field, and that is exactly what gets dropped when
#| the check is written inline for the fifth time.
sub want($table, Str:D $field, $type, IO::Path:D $path, Str:D $section) {
    my $value = $table{$field};

    fail X::Ronosathwasha::Declaration::BadValue.new(
        :$path, :field("$section.$field"), :subject('the configuration'), :found(Nil),
    ) without $value;

    fail X::Ronosathwasha::Declaration::BadValue.new(
        :$path, :field("$section.$field"), :subject('the configuration'), :found($value),
    ) unless $value ~~ $type;

    $value;
}

#| Load the configuration. No return type; see `Ronosathwasha::Types`.
sub load-config(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my %model    = require-table($doc, 'model');
    my %context  = require-table($doc, 'context');
    my %server   = require-table($doc, 'server');
    my %sampling = require-table($doc, 'sampling');

    # `~` expanded once, here. `IO::Path.resolve` would not do it: the tilde is a
    # shell convention rather than a filesystem one, so an unexpanded path names a
    # directory called `~` in the working directory and the error is a confusing
    # "no such file" against a plausible-looking string.
    my Str $raw = want(%model, 'path', Str, $path, 'model');
    my IO::Path $weights = $raw.starts-with('~/')
        ?? $*HOME.add($raw.substr(2))
        !! $raw.IO;

    # Checked for existence here rather than at first use, because the first use is
    # an HTTP request to a server that loaded the file at startup, and the error
    # arrives as a refused connection minutes after the real mistake.
    fail X::Ronosathwasha::Declaration::BadValue.new(
        :$path, :field<model.path>, :subject('the model weights'), :found(~$weights),
    ) unless $weights.e;

    # `Budget.TWEAK` refuses a reservation that leaves nothing, so an impossible
    # budget fails while being constructed rather than when a prompt first does not
    # fit. That check lives there and is not repeated here.
    my $budget = Budget.new(
        :total(want(%context, 'total', Int, $path, 'context')),
        :reserved(want(%context, 'reserved', Int, $path, 'context')),
    );

    return Config.new(
        :model(ModelFile.new(
            :name(want(%model, 'name', Str, $path, 'model')),
            :quantisation(want(%model, 'quantisation', Str, $path, 'model')),
            :path($weights),
        )),
        :$budget,
        :server(Server.new(
            :url(want(%server, 'url', Str, $path, 'server')),
            :timeout-seconds(want(%server, 'timeout_seconds', Int, $path, 'server')),
        )),
        :sampling(Sampling.new(
            :temperature(want(%sampling, 'temperature', Numeric, $path, 'sampling')),
            :top-p(want(%sampling, 'top_p', Numeric, $path, 'sampling')),
            :top-k(want(%sampling, 'top_k', Int, $path, 'sampling')),
            :thinking(?want(%sampling, 'thinking', Bool, $path, 'sampling')),
        )),
    );

    CATCH { default { .fail } }
}
