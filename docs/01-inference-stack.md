# 01 — Inference stack & voice containers

The shared brain and senses for every persona. Three OpenAI‑compatible services on
one GPU box (`INFER_HOST`), plus the OpenClaw gateway on `AGENT_HOST`. Build this
once; all personas share it.

```
INFER_HOST (GPU)                          AGENT_HOST (workstation)
┌────────────────────────────┐           ┌──────────────────────────────┐
│ vLLM        :8000  LLM      │◀──HTTP────│ OpenClaw gateway (all chat)  │
│ Qwen3-ASR   :8001  STT      │◀──HTTP────│ matrix-voip-agent-<name> ×N  │
│ Qwen3-TTS   :8002  voice    │◀──HTTP────│ PipeWire user session        │
└────────────────────────────┘           └──────────────────────────────┘
```

All three speak the OpenAI API shape (`/v1/models`, `/v1/chat/completions`,
`/v1/audio/transcriptions`, `/v1/audio/speech`), so every consumer is just a base URL
+ a key. Keep them on a private network; expose nothing to the internet here.

---

## 1. LLM — vLLM (`:8000`)

Serve a capable open model. The reference roster runs a Qwen3‑class MoE in two
flavors off the same server: a **fast** alias (thinking off, for voice latency) and a
**deep** alias (thinking on, for chat). Use whatever model fits your GPU.

```bash
docker run -d --name vllm --gpus all --restart unless-stopped \
  -p 8000:8000 -v ~/models:/models \
  vllm/vllm-openai:latest \
  --model /models/your-llm \
  --served-model-name qwen36-deep \
  --max-model-len 32768 --gpu-memory-utilization 0.80
```

- Expose two **served‑model names** (`qwen36-fast`, `qwen36-deep`) if your serving
  layer supports per‑request thinking toggles; otherwise run two configs or toggle
  `chat_template_kwargs`/`enable_thinking` per request. Personas reference these names
  via `--model vllm/qwen36-deep` (chat) and `VLLM_VOICE_FAST_MODEL` (calls).
- vLLM exposes Prometheus metrics at `/metrics` — handy for a dashboard
  (`vllm:generation_tokens_total`, `vllm:num_requests_running`).

Verify: `curl -s http://INFER_HOST:8000/v1/models`.

## 2. STT — Qwen3‑ASR (`:8001`)

Speech‑to‑text for calls. An OpenAI‑compatible ASR endpoint (`/v1/audio/transcriptions`).

```bash
docker run -d --name qwen3-asr --gpus all --restart unless-stopped \
  -p 8001:8001 -v ~/models:/models \
  your/qwen3-asr-openai:latest --served-model-name qwen3-asr
```

Personas point at it with `MAC_ASR_URL=http://INFER_HOST:8001/v1` and
`MAC_ASR_MODEL=qwen3-asr`. (whisper.cpp is a fine fallback — `WHISPER_ENABLED=true`
with a local `ggml-base.bin` — but a stronger ASR cuts call latency and error rate.)

> **Silence/hallucination gotcha:** some ASR models emit a phantom phrase on pure
> silence (a stock training caption). Gate on input energy/VAD before transcribing,
> or filter known phantom strings, so the persona doesn't "hear" words during quiet.

## 3. Voice — Qwen3‑TTS (`:8002`)

The persona's voice. One server does both **cloning** (from reference audio) and
**design** (from a text description). OpenAI‑compatible `/v1/audio/speech`.

```bash
docker run -d --name qwen3-tts --gpus all --restart unless-stopped \
  -p 8002:8002 -v ~/models:/models -v ~/voices:/voices \
  your/qwen3-tts-openai:latest --served-model-name qwen3-tts-clone
```

- `/voices` holds per‑persona reference clips and/or saved designed‑voice seeds.
- Personas select a voice with `VOXTRAL_VOICE=<name>` and a mode with
  `VOXTRAL_TTS_MODE=voice_clone|voice_design`. Full usage in
  [docs/06](06-voice-clone-or-design.md).

> **Stream wedge gotcha:** long‑running TTS servers can wedge mid‑stream under load.
> Keep a one‑liner to bounce it (`docker restart qwen3-tts`) and a healthcheck.

---

## OpenClaw gateway

The orchestrator that hosts chat for **every** agent in one process and talks to the
LLM. Install per the OpenClaw docs, then run it as a user service on `AGENT_HOST`:

```bash
systemctl --user enable --now openclaw-gateway.service
systemctl --user status openclaw-gateway.service
```

Point its model provider at `http://INFER_HOST:8000/v1` (key optional on a trusted
LAN). Agents you add later (`openclaw agents add …`) all run inside this gateway.

### PipeWire (required for calls)

The voice agents bridge WebRTC audio through PipeWire virtual devices, so
`AGENT_HOST` needs a running PipeWire user session (a normal desktop session, or a
headless one via `systemctl --user` + `XDG_RUNTIME_DIR`). Confirm:

```bash
systemctl --user is-active pipewire pipewire-pulse
which pw-loopback pw-play pw-record
```

---

## Network & sizing notes

- **Two boxes is convenient, not required.** Collapse to one box by running the
  containers and the gateway together; just mind GPU vs CPU/RAM contention.
- **Concurrency, not count, drives GPU sizing.** 30 idle personas cost nothing; five
  simultaneous calls each stream LLM + TTS. Watch `vllm:num_requests_running`.
- **Keep inference private.** Firewall `:8000/:8001/:8002` to the LAN/VPN. The only
  things that should face the internet are the homeserver's `:443` and TURN's relay
  ports ([docs/03](03-turn-and-webrtc.md)).

Next: [docs/02 — Matrix homeserver](02-matrix-homeserver.md).
