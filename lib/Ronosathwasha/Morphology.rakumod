=begin pod

=head1 Ronosathwasha::Morphology

The productive morphemes, as declared in C<data/morphology.toml>.

This is the module the declaration file was created for. Everything the grammar
needs to know about an affix is answered here: what job it does, which side of
its host it attaches to, which alternant a given stem selects, and whether it is
still the language's answer.

The method that pays for the arrangement is C<form-for>. It has no special case
for the anti-harmonic negator, because the declaration already crossed the two
alternants and the same lookup therefore gives the right form for all of them.

=end pod

unit module Ronosathwasha::Morphology;

use Ronosathwasha::Types;
use Ronosathwasha::Data;

#| Asking which alternant a disharmonic stem selects has no answer, because
#| such a stem has no harmony class to select with. That is a question about a
#| broken word rather than a broken declaration, so it gets its own type.
class X::Morphology::MixedStem is Exception is export {
    has Str $.morpheme is required;

    method message(--> Str) {
        "$!morpheme has no alternant for a stem that is neither front nor back"
    }
}

class Morpheme is export {
    has Str               $.id          is required;
    has Role              $.role        is required;
    has Host              $.host        is required;
    has Position          $.position    is required;
    has Alternation       $.alternation is required;
    has LanguageStatus    $.status      is required;
    has OrthographyStatus $.orthography is required;

    #| Set for `Alternating` and `AntiHarmonic`. Named for the stem class that
    #| selects the form, not for the form's own vowel, which is why the negator
    #| needs no special handling anywhere downstream.
    has Str $.front-stem;
    has Str $.back-stem;

    #| Set for `Invariant` and `Unpaired`, which have one form between them.
    has Str $.form;

    has Str $.superseded-by;
    has Int $.decision;

    #| Every surface form this morpheme can take.
    method forms(--> Seq) {
        ($!form, $!front-stem, $!back-stem).grep(*.defined);
    }

    #| The form this morpheme takes with a stem of the given class.
    #|
    #| A neutral stem selects the front alternant, which is the rule as decided
    #| rather than a fallback: a word with no backness is compatible with either
    #| class and the language picks one.
    method form-for(VowelProfile:D $profile --> Str) {

        return $!form with $!form;

        fail X::Morphology::MixedStem.new(:morpheme($!id)) if $profile == MixedWord;

        $profile == BackWord ?? $!back-stem !! $!front-stem;
    }

    method is-current(--> Bool) { $!status == Current }
}

class Morphology is export {
    has Morpheme @.morphemes is required;

    method current    { @!morphemes.grep(*.status == Current)    }
    method superseded { @!morphemes.grep(*.status == Superseded) }

    method by-id(Str:D $id) {
        @!morphemes.first(*.id eq $id);
    }

    #| Every surface form any current morpheme can take. This is the set that
    #| must agree with the lexicon's bound morphology, and the test that asserts
    #| it is what keeps the two files from drifting while both hold the forms.
    method current-forms(--> Set) {
        self.current.map({ .forms.Slip }).Set;
    }

    #| Every morpheme that can be spelled this way, current or not.
    #|
    #| This is the query that keying by identity exists to allow. `tho` returns
    #| two: the back future, and the question marker decision 15 retired. Asked
    #| of a form alone, the question genuinely has two answers, and a file keyed
    #| by form could not have represented the second one at all.
    method claiming(Str:D $form) {
        @!morphemes.grep({ .forms.first($form).defined });
    }
}

# The declaration's vocabulary, mapped once, at the boundary. The TOML says
# "harmonic" and "neutral" because those are the linguistic terms; the enum
# says `Alternating` and `Invariant` because inside the program the useful
# distinction is how many forms there are and what picks between them.
my constant %ROLE = (
    'tense'      => Tense,      'aspect'     => Aspect,
    'polarity'   => Polarity,   'speech-act' => SpeechAct,
    'modality'   => Modality,   'case'       => Case,
    'number'     => Number,     'possession' => Possession,
    'nonfinite'  => Nonfinite,  'locative'   => Locative,
);

my constant %HOST = (
    'verb' => VerbStem, 'noun' => NounStem, 'nominal' => NominalStem,
);

my constant %POSITION = (
    'prefix' => Prefix, 'suffix' => Suffix,
);

my constant %ALTERNATION = (
    'harmonic'      => Alternating,
    'anti-harmonic' => AntiHarmonic,
    'neutral'       => Invariant,
    'none'          => Unpaired,
);

my constant %STATUS = (
    'current' => Current, 'superseded' => Superseded, 'undecided' => Undecided,
);

#| Look one declared string up, failing with the field and the value rather
#| than defaulting. A typo in an alternation would otherwise become a silent
#| harmony rule.
sub decode(%table, $found, Str:D $field, Str:D $subject, IO::Path:D $path) {
    my $value = %table{ $found // '' };

    fail X::Declaration::BadValue.new(:$path, :$field, :$subject, :$found)
        without $value;

    $value;
}

#| Load the morphemes. No return type; see `Ronosathwasha::Types`.
sub load-morphology(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Morpheme @morphemes = @(require-table($doc, 'morpheme')).map: -> %m {
        my Str $id = ~(%m<id> // '');

        fail X::Declaration::BadValue.new(
            :$path, :field<id>, :subject('a morpheme'), :found(%m<id>),
        ) unless $id.chars;

        my $alternation = decode(%ALTERNATION, %m<alternation>, 'alternation', $id, $path);

        # An alternating morpheme needs both alternants and an invariant one
        # needs its single form. Declaring the wrong pair is the mistake this
        # file most invites, so it is checked here rather than surfacing later
        # as an undefined form in the middle of a realized word.
        my $paired = $alternation == Alternating | AntiHarmonic;

        fail X::Declaration::BadValue.new(
            :$path,
            :field($paired ?? 'front_stem and back_stem' !! 'form'),
            :subject($id),
            :found(%m<alternation>),
        ) unless $paired
            ?? (%m<front_stem>.defined && %m<back_stem>.defined)
            !! %m<form>.defined;

        Morpheme.new(
            :$id,
            :role(decode(%ROLE, %m<role>, 'role', $id, $path)),
            :host(decode(%HOST, %m<attaches_to>, 'attaches_to', $id, $path)),
            :position(decode(%POSITION, %m<position>, 'position', $id, $path)),
            :$alternation,
            :status(decode(%STATUS, %m<status>, 'status', $id, $path)),
            :orthography((%m<writable> // True) ?? Writable !! NeedsRespelling),
            :front-stem(%m<front_stem>.defined ?? ~%m<front_stem> !! Str),
            :back-stem(%m<back_stem>.defined ?? ~%m<back_stem> !! Str),
            :form(%m<form>.defined ?? ~%m<form> !! Str),
            :superseded-by(%m<superseded_by>.defined ?? ~%m<superseded_by> !! Str),
            :decision(%m<decision>.defined ?? %m<decision>.Int !! Int),
        );
    }

    return Morphology.new(:@morphemes);

    CATCH { default { .fail } }
}
