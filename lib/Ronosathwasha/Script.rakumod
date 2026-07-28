=begin pod

=head1 Ronosathwasha::Script

The phonological inventory, as declared in C<data/script.toml>.

Only what the chatbot needs is parsed. Glyph names, IPA, places and manners are
the font pipeline's business and stay in the file; this module reads the
letters and, for vowels, their backness, because backness is what harmony is
made of.

=end pod

unit module Ronosathwasha::Script;

use Ronosathwasha::Types;
use Ronosathwasha::Data;

class Vowel is export {
    has Str      $.roman    is required;
    has Backness $.backness is required;
    has Int      $.offset   is required;
}

class Consonant is export {
    has Str $.roman  is required;
    has Int $.offset is required;
}

class Script is export {
    has Vowel     @.vowels     is required;
    has Consonant @.consonants is required;

    #| The backness of a vowel, or an undefined `Backness` if the character is
    #| not a vowel of this language. Undefined rather than a failure: asking
    #| about an arbitrary character is a reasonable question with a reasonable
    #| negative answer, not a broken declaration.
    method backness-of(Str:D $roman --> Backness) {
        with @!vowels.first(*.roman eq $roman) -> $vowel {
            return $vowel.backness;
        }

        Backness;
    }

    method is-vowel(Str:D $roman --> Bool) {
        so @!vowels.first(*.roman eq $roman);
    }
}

# The declaration's vocabulary, mapped once. `data/script.toml` says "front",
# "back" and "central" because that is the phonological term, and the enum says
# the same thing in Raku. Anything outside this table is a declaration this
# code does not understand, which is a failure rather than a default.
my constant %BACKNESS = (
    front   => Front,
    back    => Back,
    central => Central,
);

#| Load the inventory.
#|
#| There is no guard between these steps and that is the point. A failed
#| `read-toml` produces an inert `Failure`; `require-table` refuses it at its
#| `RawDocument:D` parameter and throws the original exception; the `CATCH`
#| below turns that back into an inert value for this sub's own caller. The
#| failure track runs underneath the code rather than through it.
#|
#| No return type, for the reason given in `Ronosathwasha::Types`.
sub load-script(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Vowel @vowels = @(require-table($doc, 'vowel')).map: -> %v {
        my $backness = %BACKNESS{ %v<backness> // '' };

        fail X::Declaration::BadValue.new(
            :$path,
            :field<backness>,
            :subject("vowel { %v<roman> // '?' }"),
            :found(%v<backness>),
        ) without $backness;

        Vowel.new(:roman(~%v<roman>), :$backness, :offset(%v<offset>.Int));
    }

    my Consonant @consonants = @(require-table($doc, 'consonant')).map: -> %c {
        Consonant.new(:roman(~%c<roman>), :offset(%c<offset>.Int));
    }

    return Script.new(:@vowels, :@consonants);

    CATCH { default { .fail } }
}
