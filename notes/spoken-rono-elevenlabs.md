# Spoken Rono with ElevenLabs

This is a repeatable voice experiment, not a pronunciation authority.
ElevenLabs receives Rono romanisation rather than the language's declared IPA,
so it chooses phonemes and prosody for itself. A generated take can answer
questions about intelligibility, rhythm, and affect. It cannot establish how a
Rono word is pronounced.

Use `make speak` when the declared phoneme sequence is the thing being tested.
That path transcribes the inventory to espeak-ng phonemes directly.

## First experiment

Recorded on 2026-08-04 using the ElevenLabs Text to Speech web application.

```text
Nasa tari thətaswethe luru lari yayi thwame.
```

> Your house will be a fire elemental's house, and I like it.

The take lasted about two seconds and cost 44 text credits. Roger did not make
the sentence sound especially menacing. This is an observation about that take,
not about the sentence or Rono prosody.

## Repeat the take

1. Open <https://elevenlabs.io/app/speech-synthesis/text-to-speech> and sign in.
2. Paste the Rono sentence exactly as written above into the main text area.
3. Select **Roger: Laid-Back, Casual, Resonant** and **Eleven Multilingual v2**.
4. Set the controls to the captured values below.
5. Generate the speech and listen to the result.

| Control | Value |
|---|---:|
| Speed | 1.00 |
| Stability | 0.50 |
| Similarity | 0.75 |
| Style exaggeration | 0.00 |
| Language override | off |
| Speaker boost | on |
| Output format | MP3, 44.1 kHz, 128 kbps |

The model and voice are named rather than described as defaults because web
defaults can change. Repeated generations may still differ. Preserve the text
and settings when comparing takes, and change one control at a time when the
control itself is the experiment.
