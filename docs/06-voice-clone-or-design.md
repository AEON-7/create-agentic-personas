# 06 — Voice: clone or design

The persona's voice is a Qwen3‑TTS server ([docs/01](01-inference-stack.md), `:8002`)
plus a per‑persona selection in `~/voip-<name>/.env`. Two ways to get a distinct,
persistent voice — pick one per persona.

> The env keys are prefixed `VOXTRAL_*` for historical reasons; they drive **Qwen3‑TTS**
> now. `VOXTRAL_TTS_MODE` chooses clone vs design.

```
                    ┌─ voice_clone  ←─ 10–30s of clean reference audio of a real timbre
VOXTRAL_TTS_MODE ──▶│
                    └─ voice_design ←─ a text DESCRIPTION of a voice (imitates no one)
```

---

## A) Clone — from reference audio

Use when you have the right to a specific timbre: **your own voice**, a voice you've
**licensed/consented**, or a **public‑domain recording**.

1. Capture/obtain **10–30 seconds** of clean, single‑speaker audio — no music, no
   overlap, minimal noise, consistent mic. Quality of this clip dominates the result.
2. Place it where the TTS server reads voices (e.g. `~/voices/ada/reference.wav`,
   mounted into the container at `/voices`).
3. Configure the persona:

```ini
VOXTRAL_TTS_MODE=voice_clone
VOXTRAL_VOICE=ada
VOXTRAL_MODEL=qwen3-tts-clone
VOXTRAL_BASE_URL=http://INFER_HOST:8002/v1
VOXTRAL_LANGUAGE=English
VOXTRAL_STREAMING=true
```

**Consent is mandatory.** Don't clone a real person's voice to impersonate or deceive.
See [`SECURITY.md`](../SECURITY.md).

## B) Design — from a description

Use when you want a fitting voice that imitates no specific living person (great for
historical/fictional personas). You describe it; the model synthesizes it.

```ini
VOXTRAL_TTS_MODE=voice_design
VOXTRAL_VOICE=ada
VOXTRAL_VOICE_DESCRIPTION=A warm, curious, precise English mathematician; measured cadence, bright enthusiasm, mid-low pitch.
VOXTRAL_VOICE_STYLE_FIELD=instructions
VOXTRAL_LANGUAGE=English
```

Write the description like casting notes: **age, gender, accent, pitch, pace, texture,
emotional default**. Concrete adjectives beat vibes. Iterate the wording until the
audition matches the character on the page.

### The `tts-voice-designer` skill

For serious voice work there's a dedicated skill (Qwen3‑TTS VoiceDesign in ComfyUI):
it builds the workflow, supports **design from scratch, cloning from reference, and a
"three‑lock" preservation** system so a designed voice stays consistent across
sessions. Reach for it when you want to *craft and lock* a signature voice rather than
one‑shot a description.

> **Don't put stage directions in spoken text.** When the persona speaks via the
> gateway's simple `tts` tool, the `text` field is spoken **literally** — shape emotion
> through wording and punctuation, not `(whispering)` annotations. Voice‑design
> instructions belong in the `VOXTRAL_VOICE_DESCRIPTION` / `voice_instruct` field, never
> in the words to be spoken.

---

## Audition before you commit

Render one line through the exact server + voice the persona will use:

```bash
curl -s http://INFER_HOST:8002/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-tts-clone","voice":"ada","input":"Hello — this is a voice test."}' \
  --output /tmp/ada-test.wav
pw-play /tmp/ada-test.wav    # or: afplay / ffplay
```

Tune until it's right, *then* wire it into calls. Re‑auditioning after a calls bug
saves you chasing a TTS problem inside the WebRTC stack.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Robotic / wrong timbre | reference too short/noisy | 10–30 s clean single‑speaker clip |
| Voice drifts between calls | design re‑synthesizing differently | save a seed / use the skill's voice‑lock |
| Stage directions spoken aloud | directions in `text` | move them to the description field |
| Long pauses / cut‑offs | TTS stream wedged or token cap | bump `VOXTRAL_TTS_MAX_NEW_TOKENS`; restart the TTS container |
| Latency too high on calls | deep model + long responses | use the fast model for voice; cap response length |

Next: [docs/07 — VOIP profile](07-voip-profile.md).
