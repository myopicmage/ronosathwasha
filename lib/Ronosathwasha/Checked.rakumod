=begin pod

=head1 Ronosathwasha::Checked

Functional update that complains about a misspelled field.

=head2 What this replaces

C<.clone(:attr(...))> is Raku's copy-with-changes, and its signature is
C<(Mu $:: |)>: a capture that accepts anything at all. It has to be, because one
method serves every class in the language. The consequence is that
C<$state.clone(:trns(@x))> is not an error. It is a copy with nothing changed,
and the value is simply wrong somewhere later with nothing pointing at the line
that did it.

Silent no-op is the worst failure mode available here. Worse than an exception,
much worse than a compile error, because it produces plausible data.

=head2 What it costs, honestly

This is a runtime check, not a compile-time one. F# gives you C<{ r with X = 1 }>
verified by the compiler and no way to opt out; this catches the same mistake at
the moment it is made rather than at the moment it matters.

That is most of the value and not all of it. The trade Raku is offering is that
the metaobject protocol hands you C<.^attributes> at runtime, so a check the
built-in does not do is twelve lines away.

Inherited attributes count. C<.^attributes> reports only what a class declares
itself, so the whole method resolution order is walked; otherwise every subclass
would reject the fields it got from its parent.

=end pod

unit module Ronosathwasha::Checked;

use X::Ronosathwasha;

role Checked is export {

    #| Copy with changes, refusing a field this class does not have.
    method with(*%changes) {
        my Set $known = self.^mro
            .map({ .^attributes.Slip })
            .map({ .name.substr(2) })
            .Set;

        my @unknown = %changes.keys.grep({ not $known{$_} }).sort;

        die X::Ronosathwasha::NoSuchAttribute.new(
            :type(self.^name),
            :wanted(@unknown),
            :known($known.keys.sort),
        ) if @unknown;

        self.clone(|%changes);
    }
}
