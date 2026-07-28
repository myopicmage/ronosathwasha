=begin pod

=head1 Ronosathwasha::Chatbot

The distribution's entry point. Deliberately almost empty: this stop exists to
prove the arrangement rather than to implement behaviour. The grammar, the
morphology and the model protocol arrive in later stops as their own modules.

=end pod

unit module Ronosathwasha::Chatbot;

#| The repository root, derived from this file's own location rather than from
#| the working directory, so a test, a script and the CLI all find `data/` in
#| the same place no matter where they were started.
#|
#| This holds while the distribution is run from its source tree, which is the
#| only way it is run. Installing it into a zef repository would move `$?FILE`
#| into the store and leave `data/` behind, so an installed copy would need the
#| declarations as distribution resources instead.
sub repository-root(--> IO::Path) is export {
    $?FILE.IO.parent(3);
}
