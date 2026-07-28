=begin pod

=head1 Ronosathwasha::Data

The single place a declaration file is read. Every other module receives typed
values, and none of them import a TOML parser.

That is the point of the module rather than a tidiness preference. One
dependency turns bytes into data structures, so replacing it later is one file,
and no downstream code can quietly start believing a hash is a declaration.

Failures leave here as inert C<Failure> values wrapping the typed exceptions in
L<Ronosathwasha::Types>. See that module for the two behaviours that make this
work and the one that would silently break it.

=end pod

unit module Ronosathwasha::Data;

use Config::TOML;
use Ronosathwasha::Types;

#| A parsed TOML file that has not yet been given meaning. It carries its own
#| path so that anything reading it can report a failure against the file
#| rather than against a table name floating free of one.
class RawDocument is export {
    has IO::Path $.path is required;
    has %.data          is required;
}

#| Read one TOML file.
#|
#| No return type is declared, deliberately. Constraining this to
#| `--> RawDocument` would make every `fail` below throw at the point of
#| failure instead of returning an inert value, which is exactly the behaviour
#| this is written to avoid.
sub read-toml(IO::Path:D $path) is export {

    fail X::Declaration::Unreadable.new(:$path, :reason('no such file')) unless $path.e;

    fail X::Declaration::Unreadable.new(:$path, :reason('not a file')) unless $path.f;

    my %data;

    {
        %data = from-toml(:file(~$path));

        # `CATCH` is installed *inside* the scope it guards rather than wrapped
        # around it. `fail` here converts a thrown parser error into the same
        # inert value the guards above produce, so every way this sub fails
        # looks identical to a caller.
        CATCH {
            default {
                fail X::Declaration::Unreadable.new(
                    :$path,
                    :reason(.message.lines.head // ~$_),
                );
            }
        }
    }

    RawDocument.new(:$path, :%data);
}

#| Look up a required table.
#|
#| `$doc` is deliberately unconstrained. Writing `RawDocument:D` there looks
#| stricter and is worse: a `Failure` handed straight from `read-toml` would
#| unwrap to the original exception, but the same failure arriving through a
#| variable would throw `X::TypeCheck::Binding::Parameter` and lose the cause.
#| A caller adding one `my $doc = ...` would silently change which exception
#| their user sees.
#|
#| Left open, the failure surfaces on the first method call below, which is
#| reliable in both cases.
sub require-table($doc, Str:D $table) is export {

    fail X::Declaration::MissingTable.new(:path($doc.path), :$table)
        unless $doc.data{$table}:exists;

    $doc.data{$table};
}
