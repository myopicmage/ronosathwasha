=begin pod

=head1 Ronosathwasha::Script

The phonological inventory, as declared in `data/script.toml`.

Only what the chatbot needs is parsed. The glyph names, IPA, places and manners
are the font pipeline's business and stay in the file; this module reads the
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

class Script does LoadOutcome is export {
    has Vowel     @.vowels     is required;
    has Consonant @.consonants is required;

    #| Vowel by romanisation, or `Backness` undefined if the character is not a
    #| vowel of this language. Callers get a type object rather than a thrown
    #| exception, so `.defined` is the question to ask.
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
# "back" and "central" because that is the phonological term; the enum says the
# same thing in Raku. Anything outside this table is a declaration this code
# does not understand, which is a load failure and not a default.
my constant %BACKNESS = (
    front   => Front,
    back    => Back,
    central => Central,
);

sub load-script(IO::Path:D $path --> LoadOutcome) is export {
    my $doc = read-toml($path);

    return $doc if $doc ~~ LoadFailure;

    my $raw-vowels = require-key($doc, 'vowel');
    return $raw-vowels if $raw-vowels ~~ LoadFailure;

    my $raw-consonants = require-key($doc, 'consonant');
    return $raw-consonants if $raw-consonants ~~ LoadFailure;

    my Vowel @vowels;

    for @$raw-vowels -> %v {
        my $backness = %BACKNESS{ %v<backness> // '' };

        return LoadFailure.new(
            :$path,
            :reason("vowel { %v<roman> // '?' } has unknown backness { %v<backness>.raku }"),
        ) without $backness;

        @vowels.push: Vowel.new(
            :roman(~%v<roman>),
            :$backness,
            :offset(%v<offset>.Int),
        );
    }

    my Consonant @consonants = @$raw-consonants.map: -> %c {
        Consonant.new(:roman(~%c<roman>), :offset(%c<offset>.Int));
    };

    Script.new(:@vowels, :@consonants);
}
