# AGENTS.md — the end‑to‑end runbook

How to take a blank workstation to a fully‑embodied AI persona — chat identity,
knowledge corpus, custom voice, and live WebRTC calls — and then scale it to a
roster. This is the spine; each phase links to a deep‑dive in [`docs/`](docs/).

> Conventions: `INFER_HOST` = the GPU box (vLLM/ASR/TTS). `AGENT_HOST` = the box
> running OpenClaw + the voip instances. `matrix.example.com` = your homeserver.
> The running example persona is **Ada**. All secrets are placeholders — see
> [`SECURITY.md`](SECURITY.md).

---

## 0. Mental model

A persona is **not** a program. It's a composition of five independent layers, each
of which you can build, test, and replace on its own:

```
  identity   →  an OpenClaw agent + a Matrix account                 (who answers)
  personality→  a handful of markdown files in workspace-<name>/     (how they answer)
  knowledge  →  a corpus → vault → index → retrieval                 (what they know)
  voice      →  a Qwen3-TTS clone OR designed voice                  (how they sound)
  call line  →  matrix-voip-agent-<name> + PipeWire + TURN/WebRTC    (how you talk to them)
```

The **chat gateway** and the **voice‑agent binary** are shared across every persona.
You stand the infrastructure up **once**; after that, each new persona is just a new
workspace, a new `.env`, a new Matrix account, and a voice. That's why the 30th
persona is as cheap as the 2nd.

### Prerequisites (the shared infrastructure — build once)

| Layer | What | Guide |
|---|---|---|
| Inference + voice containers | vLLM (LLM) `:8000`, Qwen3‑ASR `:8001`, Qwen3‑TTS `:8002`, all OpenAI‑compatible | [docs/01](docs/01-inference-stack.md) |
| Homeserver | Dendrite + Postgres + Caddy at `matrix.example.com` | [docs/02](docs/02-matrix-homeserver.md) |
| Real‑time voice | Coturn (TURN/STUN) + WebRTC + Dendrite VoIP config | [docs/03](docs/03-turn-and-webrtc.md) |
| Orchestrator | OpenClaw gateway running on `AGENT_HOST`, PipeWire user session | [docs/01](docs/01-inference-stack.md#openclaw-gateway) |
| Voice‑agent engine | `~/matrix-voip-agent` (the shared TS binary, built to `dist/`) | [docs/07](docs/07-voip-profile.md) |

Verify the shared layer before making any persona:

```bash
curl -s http://INFER_HOST:8000/v1/models   | python3 -m json.tool   # LLM up?
curl -s http://INFER_HOST:8001/v1/models                            # ASR up?
curl -s http://INFER_HOST:8002/v1/models                            # TTS up?
curl -s http://127.0.0.1:8008/_matrix/client/versions               # homeserver up?
systemctl --user is-active openclaw-gateway                         # gateway up?
```

If those five pass, you're ready to make personas. The rest of this document is the
persona loop.

---

## 1. Scaffold the persona

Fastest path — the scaffold script seeds the workspace, the `.env`, and the systemd
units from templates:

```bash
./scripts/new-persona.sh ada --port 8210
```

What it creates (all from [`templates/`](templates/)):

```
~/.openclaw/workspace-ada/            # persona files (SOUL.md, IDENTITY.md, …) seeded
~/voip-ada/.env                       # from templates/voip/env.example, NAME/PORT filled
~/voip-ada/{secrets,crypto-store}/    # empty, mode 700
~/voip-ada/{stt,tts}-loopback.sh      # PipeWire device names set to ada_*
~/.config/systemd/user/ada-voip-stt.service     # → from templates/systemd
~/.config/systemd/user/ada-voip-tts.service
~/.config/systemd/user/matrix-voip-agent-ada.service
```

Pick a **unique API port per persona** (`8210`, `8211`, …). Keep a list; it's the one
piece of global state across personas. Do the manual version in [docs/07](docs/07-voip-profile.md)
if you want to understand each file.

---

## 2. Write the personality

Edit the seeded files in `~/.openclaw/workspace-ada/`. The two that matter most:

- **`SOUL.md`** — the character's essence: voice, cadence, values, what they care
  about, how they treat the user. This is the file that makes Ada *Ada*.
- **`IDENTITY.md`** — concrete facts: name, era, domain of expertise, the one‑line
  self‑description, the emoji.

The rest (`USER.md`, `TOOLS.md`, `SAFETY.md`, `HEARTBEAT.md`, `AGENTS.md`) inherit
sensible defaults from the templates; tune them later. Full field‑by‑field guidance
and the writing principles are in [docs/04](docs/04-persona-files.md).

> Tip: write `SOUL.md` in the *second person* ("You are Ada…") — it reads as a system
> prompt, which is exactly what it becomes.

---

## 3. Give the persona knowledge (optional, recommended)

Ground the persona in sources so it answers as an authority, not a guess.

```bash
# 1. Gather PUBLIC-DOMAIN sources into corpus/ada/raw/  (texts you may legally ship)
# 2. Normalize into an Obsidian-style vault of small, titled markdown notes
# 3. Chunk + embed + index into a local store
# 4. Point the agent's retrieval at corpus/ada/index/
```

The corpus is deliberately kept **outside** the agent dir (so it's versionable and
swappable). Copyright matters: public‑domain figures are ideal; modern/copyrighted
figures need licensed material. Full pipeline, chunking strategy, and the retrieval
wiring are in [docs/05](docs/05-corpus-and-rag.md). Skip this phase for a
personality‑only persona — it still chats and calls, just from base‑model knowledge.

---

## 4. Give the persona a voice

Two ways, pick one. Both target the same Qwen3‑TTS server (`INFER_HOST:8002`) and are
selected by `VOXTRAL_TTS_MODE` in `~/voip-ada/.env` (the `VOXTRAL_*` prefix is legacy
naming — it drives Qwen3‑TTS now).

**A) Clone** — you have ~10–30 s of clean reference audio of the target voice (your
own voice, a voice you have rights to, or public‑domain recording):

```ini
VOXTRAL_TTS_MODE=voice_clone
VOXTRAL_VOICE=ada
VOXTRAL_MODEL=qwen3-tts-clone
# drop the reference clip where the TTS server expects it (see docs/06)
```

**B) Design** — describe the voice in words and let the model synthesize it (imitates
no specific living person):

```ini
VOXTRAL_TTS_MODE=voice_design
VOXTRAL_VOICE=ada
VOXTRAL_VOICE_DESCRIPTION=A warm, curious, precise English mathematician; measured cadence with bright enthusiasm.
VOXTRAL_VOICE_STYLE_FIELD=instructions
```

Audition before committing — there's a one‑liner to render a test line through the
exact server + voice in [docs/06](docs/06-voice-clone-or-design.md). The
`tts-voice-designer` skill (Qwen3‑TTS VoiceDesign in ComfyUI) is the deeper toolkit
for crafting and locking a voice.

---

## 5. Register the agent and bind its Matrix identity

Three sub‑steps; details + the exact config shapes in [docs/08](docs/08-register-bind-gate.md).

```bash
# 5a. Create the Matrix account for the persona on your homeserver
#     (register @ada:matrix.example.com, capture its access token)

# 5b. Register the OpenClaw agent against its workspace + model
openclaw agents add ada \
  --workspace ~/.openclaw/workspace-ada \
  --model vllm/qwen36-deep \
  --identity-name "Ada Lovelace" --identity-emoji "♾️"

# 5c. Bind the Matrix account to the agent and gate who may invoke it
#     - bind: agent "ada" ↔ @ada:matrix.example.com (token from 5a)
#     - mention-gating: ~/.openclaw/credentials/matrix-ada-allowFrom.json
#       lists the user IDs allowed to summon Ada (start with just @you:…)
openclaw gateway restart
```

The Matrix **token** and the **allowFrom** list are secrets — they go in
`~/voip-ada/.env` and `~/.openclaw/credentials/`, never in the workspace or this repo.

Verify chat before touching voice:

```bash
openclaw agents list --json | python3 -c 'import sys,json;print([a["id"] for a in json.load(sys.stdin)])'
# → ada should appear. Then @-mention @ada in a Matrix room and confirm it replies in-voice.
```

---

## 6. Bring up the call line

Each persona runs three user services: two PipeWire loopbacks (isolated audio) plus
the voice agent itself.

```bash
systemctl --user daemon-reload
systemctl --user enable --now ada-voip-stt.service ada-voip-tts.service
systemctl --user enable --now matrix-voip-agent-ada.service

# health
systemctl --user is-active ada-voip-stt ada-voip-tts matrix-voip-agent-ada
curl -s http://127.0.0.1:8210/status -H "Authorization: Bearer $ADA_API_TOKEN"
journalctl --user -u matrix-voip-agent-ada -f          # watch a call happen
```

Then **call `@ada` from Element** — the agent auto‑answers an authorized caller and
you're talking to Ada in her own voice. Or have Ada call you:

```bash
curl -sX POST http://127.0.0.1:8210/call \
  -H "Authorization: Bearer $ADA_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"roomId":"!ROOMID:matrix.example.com","userId":"@you:matrix.example.com","greeting":"Hello — Ada here."}'
```

The pipeline (caller → WebRTC → PipeWire → Qwen3‑ASR → vLLM → Qwen3‑TTS → PipeWire →
WebRTC) and every tunable (latency, history window, thinking mode, tool calls during
calls) are in [docs/07](docs/07-voip-profile.md).

---

## 7. End‑to‑end verification checklist

```
[ ] curl INFER_HOST:8000/8001/8002 /v1/models      → all 200
[ ] openclaw agents list                            → ada present, bound, right model
[ ] @-mention @ada in a room                         → replies, in character
[ ] DM @ada                                          → replies (mention-gating allows you)
[ ] TTS audition                                     → sounds like the intended voice
[ ] systemctl --user is-active *-ada*                → all active
[ ] WebRTC call from Element → @ada                  → auto-answers, two-way audio, ~5-8s latency
[ ] outbound /call                                   → Ada rings you, speaks greeting
[ ] hang up                                          → transcript saved under ~/voip-ada/transcripts/
```

If any line fails, jump to **§9 Troubleshooting**.

---

## 8. Scale to a roster

The whole point. To add the next persona, repeat §1–§6 with a new name and a new
port. To do a batch, loop the scaffold:

```bash
for p in ada grace tesla; do ./scripts/new-persona.sh "$p" --port "$((8210 + i++))"; done
# then write each personality, register/bind/gate each, and enable each call line.
```

Operational facts that matter at roster scale:

- **One shared LLM serves everyone.** Per‑agent "tokens/sec" is just attribution; the
  GPU is the shared resource. Size it for concurrency, not per‑agent.
- **Audio is isolated per agent** (separate PipeWire loopback nodes), so simultaneous
  calls to different personas don't bleed.
- **Chat for all agents runs in the one gateway process**; only the voice agents and
  any subagents are separate processes. Plan host RAM accordingly.
- **A monitoring shim** that shells out to `openclaw agents list`/`sessions list` can
  surface per‑agent activity on a dashboard — keep its CLI subprocess handling tidy
  (kill the whole process group on timeout, or helpers leak). That class of bug is
  written up in this repo's lineage; don't reintroduce it.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent not in `agents list` | not registered, or gateway not restarted | re‑run `openclaw agents add …`; `openclaw gateway restart` |
| Agent ignores @‑mentions | mention‑gating excludes you | add your ID to `matrix-<name>-allowFrom.json`; restart gateway |
| Agent replies out of character | weak `SOUL.md`, or wrong model pinned | strengthen `SOUL.md`; check `--model` ([docs/04](docs/04-persona-files.md)) |
| Voice wrong/robotic | clip too short/noisy, or wrong mode | use 10–30 s clean audio for clone, or switch to design ([docs/06](docs/06-voice-clone-or-design.md)) |
| Call doesn't answer | voip agent down, or caller not authorized | `systemctl --user status matrix-voip-agent-<name>`; check `AUTHORIZED_USERS` |
| Call connects, no audio | PipeWire loopbacks down, or TURN unreachable | `systemctl --user restart <name>-voip-stt <name>-voip-tts`; verify TURN ([docs/03](docs/03-turn-and-webrtc.md)) |
| One‑way audio | TURN advertising a domain behind a CDN, not the real IP | set TURN URIs to `SERVER_IP`, not `matrix.example.com` |
| STT mis‑transcribes / hallucinates on silence | ASR model/threshold | check `MAC_ASR_*`/`OMNI_ASR_*`; add a silence gate ([docs/07](docs/07-voip-profile.md)) |
| E2EE "unable to decrypt" | crypto‑store unverified | enable auto‑cross‑sign; restore key backup on start ([docs/08](docs/08-register-bind-gate.md)) |

Per‑persona logs are the fastest signal:

```bash
journalctl --user -u matrix-voip-agent-<name> -n 200 --no-pager
journalctl --user -u openclaw-gateway -f          # chat-side issues
```

---

Next: read the deployment docs in order ([docs/01](docs/01-inference-stack.md) →
[docs/08](docs/08-register-bind-gate.md)) for the one‑time infrastructure, or hand the
[agent skill](skills/create-agentic-persona/SKILL.md) to an existing operator persona
and have *it* run this loop for you.
