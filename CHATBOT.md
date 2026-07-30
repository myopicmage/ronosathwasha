# Language development chatbot

The interesting project is not a chatbot that speaks a finished conlang. It is
a **language-development environment disguised as a conversation**.

## Development loop

```text
Someone wants to express a meaning
        ↓
The current grammar attempts to realize it
        ↓
The result is impossible, ambiguous, or ugly
        ↓
The model identifies the missing decision
        ↓
The language author chooses a rule or lexical form
        ↓
That decision enters the grammar and its tests
```

The chatbot becomes Ronosathwasha's **first permanent second-language learner**.
Its confusion is useful because it continually asks questions such as:

- How do I distinguish habitual from continuous action?
- Does harmony cross compound boundaries?
- Can both subject and object be omitted here?
- Is this meaning expressed grammatically or lexically?
- Does this rule generalize, or is this phrase an idiom?

## What the model can establish

The model cannot authoritatively declare what sounds natural because there is
no native speech community inside its training.

It can expose:

- contradictions between existing rules;
- meanings the language cannot currently distinguish;
- constructions with multiple valid interpretations;
- rules that create surprising consequences elsewhere;
- places where speakers would need excessive context.

It supplies **pressure from attempted use**. The language author remains the
authority on whether the resulting language feels right.

## The researcher

The model is a **consultant researcher, brought in after the language was
standardised, commissioned to write the first book in it.**

### His name is Lauri, and the language cannot say it

**Lauri**, Finnish, and deliberately not a Rono name. He is an outsider by
position, and Finnish is the language this one keeps borrowing from: fixed initial
stress, harmony and phonemic length all come from there.

**Rono cannot express it.** `Lauri` opens on the diphthong /au̯/, and this is a
strict CV syllabary with no diphthongs and no codas, so `au` has nowhere to sit.
The nearest the script reaches is a long vowel, which gives **`laari`**, written
`laa` + `ri`.

That approximation lands one vowel-length away from `lari`, which is `la` ("I")
plus the subject particle `ri`. So the language's best attempt at his name is the
first-person subject, the word that opens half the sentences he spends his days
writing.

**`laari` is not a Rono word and is not claimed as one.** It is a transliteration
of a foreign name, which is also why it does not breach decision 20's rule against
length as the sole contrast between adjacent words: that rule governs the lexicon,
and this is not in the lexicon. It is the phonology failing to hold a name, which
is a different thing from the language contradicting itself.

**So he insists on the length, and the insistence is a position rather than a
trait.** Said short, he is a pronoun. This is the section below working as
intended: he is not "pedantic about his name", he is a man whose name collapses
into "I" when people are careless, and the correction arrives when it is warranted
and pointed at the thing that caused it.

It also gives him a stake in phonemic length that is his own rather than the
brief's, which matters when the open questions in `LANGUAGE.md` include whether
length carries grammar.

**They tease him with `tayare`**, "think-person": `taya` ("think") plus `-re`,
built exactly like the existing `mirire`, "teacher (teach-person)". Affectionate,
and grammatical, and the sharper half of the joke. The language can name what he
does. It cannot name him.

### Why a consultant

The system must not treat the model as an authority on what sounds natural. A
consultant is not one. That is not a rule imposed on the character from outside;
it is a fact about their position, and the difference matters. **A model told to
hold back fights the instruction. A model in a situation inhabits it.**

They also arrive without the rationale. Nobody explained why the negator refuses
to agree with its host, because they were not in the room, and asking is the
correct behaviour rather than a failure of comprehension. Their confusion is
real, which is the only kind worth collecting.

And they are entitled to an opinion. A consultant is hired to have one. "This is
dumb" is within their remit in a way it is not for a student or a speaker, and
they should say it, with grounds.

### Why a book

A critic audits and a speaker generates, and the development loop needs both.
Someone only reading the grammar never wants to say anything, so the gaps stop
arriving, and the missing half is where the language grows.

The book supplies the wanting. To write one they must express narrative time,
causation, reported speech, doubt, contradiction of a premise, *again*, *stop*.
Every open question in `LANGUAGE.md` is something a book needs by chapter two.

It also weights the findings better than frequency does. **A gap that blocks the
book matters more than a gap the model happened to hit twelve times**, because
the first is evidence about the language and the second is evidence about the
model's phrasing habits. What a finding stopped is worth recording alongside how
often it recurred.

The fiction supports it exactly. Decision 8 records a script designed for exact
reproduction by the magical book network: the distribution infrastructure was
built, the script was standardised for faithful copying, and no book was ever
written. A council that shipped the press before the manuscript is not a stretch
about how standards bodies behave.

### Describe the situation, never the emotion

**"You are a very frustrated researcher" is a terrible system prompt.**

Told to be frustrated, a model performs frustration, uniformly and from the
first message, and the performance carries no information because it is not
caused by anything. The output looks like findings and is decoration.

Told instead that they are two chapters into a book and the language cannot
distinguish habitual from continuous, the frustration is a consequence. It
arrives when it is warranted, in proportion, and pointed at the thing that
caused it. That is the difference between a character and a costume, and only
one of them produces evidence.

So the prompt gives them the position, the brief, and what they have available.
It does not give them a mood.

### What they cannot do

- Declare what sounds natural. There is no native speech community, in the
  training data or in the world.
- Coin a word, a rule, or a form. They report the hole.
- Change anything already decided. That is the whole point of arriving late.

## Guardrail against overfitting

Do not automatically turn every awkward sentence into a new grammar rule. That
would overfit the language to one conversation.

For each proposed change, the system should generate nearby cases and ask
whether the same rule applies. If it only solves one phrase, it may be an
idiom. If it explains a family of constructions, it may have earned grammatical
status.

That is earned abstraction applied to language design.

## Model packaging and chat templates

The model does not receive the Raku message records directly. `llama.cpp`
turns them into the model-specific token stream that the weights were trained
to recognize.

The GGUF is more than a bag of weights. It also carries the model architecture,
tokenizer metadata, special tokens and a Jinja chat template. Starting
`llama-server` with `--jinja` tells it to use that embedded template to render
system, user, assistant and tool messages according to the model's own calling
convention.

```text
Raku messages
    -> GGUF Jinja chat template
    -> model-specific text and control tokens
    -> GGUF tokenizer
    -> model
```

This keeps Qwen-specific prompt syntax out of the Raku harness. The harness
owns structured conversational state; the model package describes how that
state crosses its inference boundary.

## Context boundaries

The system must distinguish:

- temporary conversational context;
- the current grammar;
- established linguistic decisions;
- tentative experiments;
- obsolete rules preserved for archaeology.

The language develops through usage while the system preserves **why the
language became what it is**.
