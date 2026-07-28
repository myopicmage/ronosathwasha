=begin pod

=head1 Ronosathwasha::Data

The single place a declaration file is read. Every other module receives typed
values or a `LoadFailure`, and none of them import a TOML parser.

That is the whole point of the module rather than a tidiness preference. There
is one dependency that turns bytes into data structures, and confining it here
means swapping it later is one file, and that no downstream code can quietly
start believing a hash is a declaration.

=end pod

unit module Ronosathwasha::Data;

use Config::TOML;
use Ronosathwasha::Types;

#| A parsed TOML file that has not yet been given meaning. It exists so the
#| reader can promise `LoadOutcome` honestly: a bare hash could not be one, and
#| widening the return type to `Any` would defeat the boundary.
class RawDocument does LoadOutcome is export {
    has IO::Path $.path is required;
    has %.data          is required;
}

#| Read one TOML file. Returns a `RawDocument` or a `LoadFailure`, never a
#| thrown exception and never a partly populated hash.
sub read-toml(IO::Path:D $path --> LoadOutcome) is export {

    return LoadFailure.new(:$path, :reason('no such file')) unless $path.e;

    return LoadFailure.new(:$path, :reason('not a file')) unless $path.f;

    my %data;

    {
        %data = from-toml(:file(~$path));

        # `CATCH` is a block installed *inside* the scope it guards rather than
        # a construct wrapped around it, which is why this sits here and not
        # around the assignment. Without the explicit `return`, a handled
        # exception resumes after the enclosing block and the sub would fall
        # through to the success path with `%data` empty.
        CATCH {
            default {
                return LoadFailure.new(:$path, :reason(.message.lines.head // ~$_));
            }
        }
    }

    RawDocument.new(:$path, :%data);
}

#| Look up a required key, reporting the file and the key when it is absent
#| rather than returning an undefined value that fails somewhere else later.
sub require-key(RawDocument:D $doc, Str:D $key --> Any) is export {
    return LoadFailure.new(:path($doc.path), :reason("missing [$key]"))
        unless $doc.data{$key}:exists;

    $doc.data{$key};
}
