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

=head2 C<hosts> describes; it does not restrict

Kevin's ruling, 2026-07-30: B<anything attaches to anything, and that is
grammatical.> Whether a given combination means something is a question about
context, not about the grammar. C<mirireme>, a tense on a noun, is a well-formed
word that nobody would say, and the language admits it rather than blocking it.

So C<hosts> records what a morpheme is I<for>, and no code may turn it into a
filter. C<declared-for> answers "is this the canonical host", never "is this
allowed". A realizer that refused an undeclared host would be inventing a rule
the language does not have, and the symptom would be a form the grammar permits
coming back as an error.

This resolves the C<LANGUAGE.md> question of whether C<attaches_to> and C<role>
are enforced. They are not, deliberately, and permanently.

=head2 One morpheme has two hosts, which is why this is a list

The question marker. On a verb it questions the predicate, which is
C<Nari tethinəme?>. On a nominal it questions the referent, and that use built
the entire interrogative series: C<toro>, C<tomwu>, C<toluumo>, C<toduruu> and
C<toðoru> are C<to> prefixed to C<ro>, C<mwu>, C<luumo>, C<duruu> and C<ðoru>,
five nouns the lexicon already declares. All five bases are back words, so all
five take C<to>, and nothing is left over.

The two uses are in complementary distribution. C<Nari toro?> needs no clause
marking because the interrogative word is already carrying the morpheme.

=end pod

unit module Ronosathwasha::Morphology;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Data;


class Morpheme is export {
    has Str               $.id          is required;
    has MorphemeRole      $.role        is required;
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

    #| The hosts this morpheme is *for*, which is not the same as the hosts it
    #| may legally attach to. Kevin's ruling on 2026-07-30: anything attaches to
    #| anything, and whether the result means something is context, not grammar.
    #| So this is descriptive and must never become a filter; see the pod.
    #|
    #| Plural because the question marker has two. On a verb it questions the
    #| predicate and on a nominal it questions the referent, and the second use
    #| is where `toro`, `tomwu`, `toluumo`, `toduruu` and `toðoru` come from.
    has Host @.hosts is required;

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

        fail X::Ronosathwasha::Form::MixedStem.new(:morpheme($!id)) if $profile == MixedWord;

        $profile == BackWord ?? $!back-stem !! $!front-stem;
    }

    #| Whether this morpheme is declared for the given host.
    #|
    #| `.grep(* == $host).elems`, never `so @!hosts.first($host)`. An enum value
    #| in Raku is numeric and the first declared is 0, so `VerbStem` is itself
    #| falsy: `first` returns the matching element and boolean context then
    #| reports no match. `Ronosathwasha::Harmony` documents the same trap, where
    #| it made every word come back neutral.
    method declared-for(Host:D $host --> Bool) {
        @!hosts.grep(* == $host).elems > 0;
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
    'tense'       => MarksTense,       'aspect'     => MarksAspect,
    'polarity'    => MarksPolarity,    'speech-act' => MarksSpeechAct,
    'modality'    => MarksModality,    'case'       => MarksCase,
    'number'      => MarksNumber,      'possession' => MarksPossession,
    'nonfinite'   => MarksNonfinite,   'locative'   => MarksLocative,
    'predication' => MarksPredication,
);

#| Which role strings a declaration may use, and what each one means.
#|
#| Exposed because it is a real question about the declaration format rather than a
#| test hook. It is also the only way to check the invariant below, since the table
#| is lexical and an enum growing without its mapping compiles perfectly.
#|
#| That is how `MarksPredication` arrived broken: the value landed in
#| `Ronosathwasha::Types` and the table was not told, so `%ROLE{'predication'}` was
#| undefined, `pick` produced a `Failure`, and it died in the constrained `$.role`
#| slot with a message about a type check and nothing about the missing string.
sub declared-roles(--> Map) is export { %ROLE }

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

    fail X::Ronosathwasha::Declaration::BadValue.new(:$path, :$field, :$subject, :$found)
        without $value;

    $value;
}

#| Decode `attaches_to`, which is a list because one morpheme has two hosts.
#|
#| Declared below `decode` because it calls it. Raku resolves a lexical sub in
#| declaration order, so the other arrangement is an undeclared-routine error at
#| compile time rather than anything subtle.
#|
#| The empty list is refused. TOML cannot express a non-empty list, so this is
#| where that invariant has to live, and without it a morpheme could silently
#| declare itself for nothing at all rather than say so.
sub decode-hosts(%m, Str:D $id, IO::Path:D $path) {
    my @found = @(%m<attaches_to> // []);

    fail X::Ronosathwasha::Declaration::BadValue.new(
        :$path, :field<attaches_to>, :subject($id), :found(%m<attaches_to>),
    ) unless @found;

    @found.map({ decode(%HOST, $_, 'attaches_to', $id, $path) });
}

#| Load the morphemes. No return type; see `Ronosathwasha::Types`.
sub load-morphology(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Morpheme @morphemes = @(require-table($doc, 'morpheme')).map: -> %m {
        my Str $id = ~(%m<id> // '');

        fail X::Ronosathwasha::Declaration::BadValue.new(
            :$path, :field<id>, :subject('a morpheme'), :found(%m<id>),
        ) unless $id.chars;

        my $alternation = decode(%ALTERNATION, %m<alternation>, 'alternation', $id, $path);

        # An alternating morpheme needs both alternants and an invariant one
        # needs its single form. Declaring the wrong pair is the mistake this
        # file most invites, so it is checked here rather than surfacing later
        # as an undefined form in the middle of a realized word.
        my $paired = $alternation == Alternating | AntiHarmonic;

        fail X::Ronosathwasha::Declaration::BadValue.new(
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
            :hosts(decode-hosts(%m, $id, $path)),
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
