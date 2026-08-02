=begin pod

=head1 Ronosathwasha::Commands

What a running conversation accepts instead of a message, declared once.

The terminal's slash commands were previously written down twice: as a chain of
string comparisons in C<Ronosathwasha::Terminal>, which knew how to run them,
and as a block of prose in C<bin/ronosathwasha-chat>, which knew how to describe
them. Neither could see the other, so adding a command left it undocumented and
removing one left a line of help pointing at nothing. The failure was silent in
both directions, which is the only kind this project keeps finding.

So the list lives here, and both of those readers derive from it. C<Terminal>
binds a handler to every declared name and refuses to build if the two sets
disagree, which turns the drift into a construction error rather than a missing
feature nobody notices. C<usage> renders the same list, and C</help> renders it
again inside the session, where somebody who has already started a conversation
can actually reach it.

The declaration deliberately carries no handlers. A handler needs the terminal's
own state, and putting a closure here would mean this module could only be read
by something holding a C<Terminal>, which is exactly what C<usage> is not.

=end pod

unit module Ronosathwasha::Commands;

#| One thing a conversation accepts in place of a message.
#|
#| C<argument> is the name a caller would see in usage, so C<'PATH'> renders as
#| C</export PATH> and also tells the dispatcher that a trailing argument is
#| allowed. A command without one matches only its exact name.
class TerminalCommand is export {
    has Str:D  $.name       is required;
    has Str:D  $.summary    is required;
    has Str     $.argument;

    #| `/quit` ends the loop rather than printing into it. Declaring that here
    #| keeps it in the help text, which is where somebody looks for it, while
    #| letting the dispatcher treat it as the one command that does not resume.
    has Bool:D $.terminates = False;

    #| What a caller types, argument included. The dispatcher matches on
    #| `name`; this is for display only.
    method spelling(--> Str) {
        $!argument.defined ?? "$!name $!argument" !! $!name;
    }

    #| Whether a line typed at the prompt is this command. An argument-taking
    #| command matches its bare name too, so `/export` alone can report its own
    #| usage rather than being sent to the model as a sentence.
    method matches(Str:D $heard --> Bool) {
        return True if $heard eq $!name;
        return False unless $!argument.defined;

        $heard.starts-with("$!name ");
    }

    #| The text after the command name, trimmed, or the empty string. Kept here
    #| rather than at the call site so the offset is computed from the name that
    #| was actually matched.
    method argument-of(Str:D $heard --> Str) {
        $heard.chars > $!name.chars
            ?? $heard.substr($!name.chars).trim
            !! '';
    }
}

#| Every slash command a session accepts, in the order a reader should meet
#| them. `/help` comes first because it is how somebody finds the rest.
sub terminal-commands(--> List) is export {
    (
        TerminalCommand.new(
            :name('/help'),
            :summary('list these commands'),
        ),
        TerminalCommand.new(
            :name('/budget'),
            :summary('show current context cost and budget'),
        ),
        TerminalCommand.new(
            :name('/parse'),
            :summary('explain the last parsed exchange'),
        ),
        TerminalCommand.new(
            :name('/gaps'),
            :summary('show language gaps found so far'),
        ),
        TerminalCommand.new(
            :name('/evidence'),
            :summary('alias for /gaps'),
        ),
        TerminalCommand.new(
            :name('/export'),
            :argument('PATH'),
            :summary('copy the durable session for review'),
        ),
        TerminalCommand.new(
            :name('/quit'),
            :summary('leave without creating another turn'),
            :terminates,
        ),
    );
}

#| How a set of bound handlers differs from the declaration, as readable
#| sentences, or the empty list when they agree.
#|
#| A pure comparison rather than a method that dies, so the invariant can be
#| tested directly instead of by building a terminal and hoping it explodes.
#| The caller decides what a disagreement is worth; C<Terminal> treats it as
#| fatal, because a session with a mis-wired command list has nothing useful
#| left to do.
#|
#| Terminating commands are excluded. C</quit> ends the loop rather than
#| printing into it, so it correctly has no handler, and requiring one would
#| mean writing a closure that can never be called.
sub command-handler-faults(@commands, %handler --> List) is export {
    my $declared = @commands.grep({ !.terminates }).map(*.name).Set;
    my $bound    = %handler.keys.Set;

    my @faults;

    my $unhandled = ($declared (-) $bound).keys.sort;
    @faults.push("declared without a handler: { $unhandled.join(', ') }")
        if $unhandled.elems;

    my $undeclared = ($bound (-) $declared).keys.sort;
    @faults.push("handled without a declaration: { $undeclared.join(', ') }")
        if $undeclared.elems;

    @faults.List;
}

#| The commands as aligned lines, without a heading, so a caller can place them
#| in whatever surrounds them.
#|
#| The column is measured rather than typed. The hand-aligned version had
#| `/quit` a space out of true, which is what a literal column always eventually
#| becomes and what nothing was ever going to catch.
sub command-help(Str:D :$indent = '  ' --> Str) is export {
    my @commands = terminal-commands();
    my Int $width = @commands.map(*.spelling.chars).max;

    @commands
        .map({ $indent ~ .spelling.fmt("%-{ $width }s") ~ '  ' ~ .summary })
        .join("\n");
}
