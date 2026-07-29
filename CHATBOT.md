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

The chatbot becomes Ronesathwasha's **first permanent second-language learner**.
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

## Context boundaries

The system must distinguish:

- temporary conversational context;
- the current grammar;
- established linguistic decisions;
- tentative experiments;
- obsolete rules preserved for archaeology.

The language develops through usage while the system preserves **why the
language became what it is**.
