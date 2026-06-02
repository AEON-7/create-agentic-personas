---
name: create-agentic-persona
description: >
  Create a new fully-embodied AI persona — an OpenClaw chat agent with a Matrix
  identity, a personality, an optional knowledge corpus, a custom Qwen3-TTS voice
  (cloned or designed), and a live WebRTC voice-call line. USE THIS SKILL whenever the
  user asks to: create/add/build/scaffold an agent, persona, character, bot, or
  council member; give an agent a voice, clone a voice, or design a voice; set up a
  voice-call line or VOIP profile for an agent; onboard a new figure/personality; or
  "make me a new <X>" where X is an agent/persona. Also trigger for: agent workspace
  setup, persona files (SOUL/IDENTITY), mention-gating, Matrix account binding for an
  agent, or adding an agent to the roster. This skill assumes the shared infrastructure
  (LLM/ASR/TTS containers, Matrix homeserver, TURN) is already running.
---

# Create an Agentic Persona

You are scaffolding a new persona end to end. A persona = **five independent layers**:
identity (OpenClaw agent + Matrix account), personality (workspace markdown), knowledge
(corpus → RAG, optional), voice (Qwen3-TTS clone or design), and a call line
(`matrix-voip-agent-<name>` + PipeWire + TURN). The infrastructure is shared and
already up; your job is the per-persona loop.

Full reference lives in this repo: [`AGENTS.md`](../../AGENTS.md) and
[`docs/`](../../docs). This skill is the operational checklist.

## Before you start — confirm with the user

Ask only what you can't infer:
1. **Name + identity** — handle (lowercase, e.g. `ada`), display name, one-line concept,
   domain of expertise, emoji.
2. **Voice** — *clone* (do they have ~10–30s of rights-cleared reference audio?) or
   *design* (describe the voice in words)? Default to **design** if unsure — it imitates
   no real person and needs no audio.
3. **Knowledge** — corpus or personality-only? If corpus: what **public-domain or
   licensed** sources? (Refuse to scrape copyrighted/living-person material.)
4. **Who may summon it** — start with just the user.

## Guardrails (non-negotiable)

- **Consent for voices.** Only clone the user's own voice, a rights-cleared voice, or a
  public-domain recording. Otherwise use voice *design*. Never help impersonate a real
  person to deceive.
- **Legal corpora only.** Public-domain or licensed. No scraping.
- **Secrets stay in `.env`/`secrets/`/`credentials/`** (all mode 600/700) — never echo a
  token into chat, a workspace file, or a commit.
- **Honesty baked in.** The persona's `SAFETY.md`/`IDENTITY.md` must state it's an AI
  interpretation, not the real person.

## The loop

### 1. Scaffold
```bash
./scripts/new-persona.sh <name> --port <UNIQUE_PORT> --display "<Display Name>" --emoji "<X>"
```
Pick the next free port (keep a registry; the roster shares one port space). This lays
down the workspace, the `~/voip-<name>/.env` (with API token + crypto pw generated),
the PipeWire loopback scripts, and the systemd units. It creates **no** account and
starts **no** services.

### 2. Write the personality
Edit `~/.openclaw/workspace-<name>/SOUL.md` (manner/voice — the high-leverage file) and
`IDENTITY.md` (facts). Write `SOUL.md` in the second person; make it specific and dense.
See [`docs/04`](../../docs/04-persona-files.md). Draft these *with* the user's input on
the character, then show them for approval.

### 3. (Optional) Build knowledge
Gather legal sources → small titled vault notes → index → wire retrieval, pointing at
`corpus/<name>/`. See [`docs/05`](../../docs/05-corpus-and-rag.md). Skip for a
personality-only persona.

### 4. Give it a voice
In `~/voip-<name>/.env` set `VOXTRAL_TTS_MODE`:
- **design:** write a vivid `VOXTRAL_VOICE_DESCRIPTION` (age/accent/pitch/pace/texture).
- **clone:** place the reference clip where the TTS server reads voices; set `voice_clone`.
**Audition** before committing (see [`docs/06`](../../docs/06-voice-clone-or-design.md)):
```bash
curl -s http://INFER_HOST:8002/v1/audio/speech -H "Content-Type: application/json" \
  -d '{"model":"qwen3-tts-clone","voice":"<name>","input":"Hello, this is a voice test."}' --output /tmp/<name>.wav
```

### 5. Create the Matrix account + register + bind + gate
- Create `@<name>:matrix.example.com`, mint an access token, put it in `~/voip-<name>/.env`
  (`MATRIX_ACCESS_TOKEN`). [`docs/08`](../../docs/08-register-bind-gate.md)
- Register and bind:
```bash
openclaw agents add <name> --workspace ~/.openclaw/workspace-<name> \
  --model vllm/qwen36-deep --identity-name "<Display Name>" --identity-emoji "<X>"
echo '{"allowFrom":["@you:matrix.example.com"]}' > ~/.openclaw/credentials/matrix-<name>-allowFrom.json
openclaw gateway restart
```
- Verify in **chat** first: `openclaw agents list` shows it; @-mention it; confirm it
  answers in character before touching voice.

### 6. Bring up the call line
```bash
systemctl --user daemon-reload
systemctl --user enable --now <name>-voip-stt <name>-voip-tts matrix-voip-agent-<name>
curl -s http://127.0.0.1:<PORT>/status -H "Authorization: Bearer $API_TOKEN"   # health
```
Then have the user call `@<name>` from Element, or place an outbound call via the API.

### 7. Verify + report
Run the checklist in [`AGENTS.md` §7](../../AGENTS.md). Report back to the user: the
handle, what voice mode, whether it has a corpus, the API port, and the exact things
they can now do (chat, call, be called). Do **not** paste any token.

## Scaling
To add several, loop step 1 with incrementing ports, then do steps 2–6 per persona.
One shared LLM serves all; audio is isolated per agent; chat shares the gateway process.

## Troubleshooting
Use the table in [`AGENTS.md` §9](../../AGENTS.md). Fastest signal:
`journalctl --user -u matrix-voip-agent-<name> -f` (voice) and
`journalctl --user -u openclaw-gateway -f` (chat).
