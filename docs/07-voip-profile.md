# 07 — VOIP profile (the call line)

This is what turns a chat persona into something you can **phone**. Each persona gets a
*voice‑call profile*: a directory of config + a trio of systemd user services that run
one shared voice‑agent engine bound to that persona's identity, voice, and audio
devices.

```
~/voip-ada/
├── .env                 # all per-agent config + secrets (mode 600)
├── secrets/             # key material (mode 700)
├── crypto-store/        # Matrix E2EE (olm/megolm) state (mode 700)
├── stt-loopback.sh      # creates ada's STT PipeWire virtual devices
└── tts-loopback.sh      # creates ada's TTS PipeWire virtual devices

systemd --user:
  ada-voip-stt.service              → runs stt-loopback.sh   (audio in)
  ada-voip-tts.service              → runs tts-loopback.sh   (audio out)
  matrix-voip-agent-ada.service     → node ~/matrix-voip-agent/dist/index.js  (the brain)
```

One **shared engine** (`~/matrix-voip-agent`, built once to `dist/`); each persona is
just a different `.env` + Matrix account + audio devices.

---

## 1. The data path

```
caller speaks
  → Element → WebRTC → Coturn relay (docs/03)
  → PipeWire loopback  (ada_stt_speaker → ada_stt_capture)
  → Qwen3-ASR  (STT, INFER_HOST:8001)               ~1–2s
  → vLLM       (LLM, INFER_HOST:8000, fast model)   ~1–2s
  → Qwen3-TTS  (voice, INFER_HOST:8002)             ~per sentence
  → PipeWire loopback  (ada_tts → ada_tts_mic)
  → WebRTC → Element → caller hears Ada
total end-to-end ~5–8s from end of speech to first audio
```

Matrix is in the *signaling* path (invite/answer) but **not** the conversation loop
after pickup — audio flows agent↔caller directly, which is what keeps latency sane.

## 2. Per‑agent audio isolation (PipeWire loopbacks)

So dozens of personas can hold simultaneous calls without bleeding into each other,
**each** gets its own virtual devices via `pw-loopback`. The seeded `stt-loopback.sh`:

```bash
#!/usr/bin/env bash
exec /usr/bin/pw-loopback \
  --capture-props="media.class=Audio/Sink   node.name=input.ada_stt_speaker node.description=ada-stt audio.position=[FL,FR]" \
  --playback-props="media.class=Audio/Source node.name=ada_stt_capture       node.description=ada-sttcap audio.position=[MONO]"
```

and `tts-loopback.sh` makes `ada_tts` / `ada_tts_mic`. The voice agent reads/writes
these by name (`PIPEWIRE_STT_*` / `PIPEWIRE_TTS_*` in `.env`). The scaffold script
fills the persona name in automatically.

## 3. The `.env` (config + secrets)

Full annotated template: [`templates/voip/env.example`](../templates/voip/env.example).
The fields that matter, grouped:

```ini
# ── Identity / Matrix ───────────────────────────────────────────────
MATRIX_HOMESERVER_URL=http://127.0.0.1:8008
MATRIX_USER_ID=@ada:matrix.example.com
MATRIX_ACCESS_TOKEN=<secret>
AUTHORIZED_USERS=@you:matrix.example.com      # who may call this persona
MATRIX_E2EE_ENABLED=true
CRYPTO_STORE_PATH=/home/USER/voip-ada/crypto-store
MATRIX_CRYPTO_STORE_PASSWORD=<secret>

# ── Brain (LLM) ─────────────────────────────────────────────────────
VLLM_BASE_URL=http://INFER_HOST:8000/v1
VLLM_VOICE_FAST_MODEL=qwen36-fast            # low-latency for calls
VLLM_VOICE_DEEP_MODEL=qwen36-deep
VLLM_VOICE_THINKING_MODE=off                 # speed on calls

# ── Ears (STT) ──────────────────────────────────────────────────────
MAC_ASR_URL=http://INFER_HOST:8001/v1
MAC_ASR_MODEL=qwen3-asr
WHISPER_ENABLED=false                         # fallback if you prefer whisper.cpp

# ── Voice (TTS) ─────────────────────────────────────────────────────
VOXTRAL_ENABLED=true
VOXTRAL_BASE_URL=http://INFER_HOST:8002/v1
VOXTRAL_VOICE=ada
VOXTRAL_TTS_MODE=voice_design                 # or voice_clone  (docs/06)
VOXTRAL_VOICE_DESCRIPTION=...                  # if design

# ── Call behavior + API ─────────────────────────────────────────────
API_PORT=8210                                 # UNIQUE per persona
API_TOKEN=<secret>                            # bearer for the /call /status API
MAX_CONCURRENT_CALLS=1
CALL_TIMEOUT_MS=1800000                       # 30 min
VOICE_HISTORY_MAX_MESSAGES=24                  # multi-turn memory window
VOICE_CALLER_NAME=Alex                        # how the persona addresses the caller
```

`MATRIX_ACCESS_TOKEN`, `API_TOKEN`, `*_API_KEY`, and `MATRIX_CRYPTO_STORE_PASSWORD` are
**secrets** — `.env` is mode `600` and git‑ignored.

## 4. The systemd units

Tiny wrappers; see [`templates/systemd/`](../templates/systemd/). The brain:

```ini
# matrix-voip-agent-ada.service
[Service]
WorkingDirectory=%h/matrix-voip-agent
EnvironmentFile=%h/voip-ada/.env
ExecStart=/usr/bin/node %h/matrix-voip-agent/dist/index.js
Restart=always
RestartSec=3
[Install]
WantedBy=default.target
```

The `-stt`/`-tts` units just `ExecStart` the loopback scripts. Bring all three up:

```bash
systemctl --user daemon-reload
systemctl --user enable --now ada-voip-stt ada-voip-tts matrix-voip-agent-ada
```

## 5. The call API

Each agent serves a small HTTP API on `API_PORT` (localhost only), bearer‑authed:

| Method | Path | Body | Purpose |
|---|---|---|---|
| POST | `/call` | `{roomId,userId,greeting?}` | persona calls someone |
| POST | `/hangup` | `{callId}` | end a call |
| GET | `/status` | — | active‑call count (also a healthcheck) |

```bash
curl -s http://127.0.0.1:8210/status -H "Authorization: Bearer $ADA_API_TOKEN"
curl -sX POST http://127.0.0.1:8210/call -H "Authorization: Bearer $ADA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"roomId":"!ROOMID:matrix.example.com","userId":"@you:matrix.example.com","greeting":"Ada here — you rang?"}'
```

This API is also what a dashboard polls for per‑agent "on a call" state.

## 6. Tunables & gotchas

- **Latency** — keep voice on the *fast* model with thinking off; cap response length;
  stream TTS per sentence so first audio arrives quickly.
- **History window** — `VOICE_HISTORY_MAX_MESSAGES` trades context for speed/cost.
- **Tools during calls** — the engine can call tools mid‑call (time, web search, run a
  command) and speak a filler phrase while they run. Don't have the persona *announce*
  tool calls; the filler is automatic.
- **Silence handling** — gate ASR on energy/VAD so the persona doesn't transcribe a
  phantom phrase during quiet (a known ASR failure mode; see [docs/01](01-inference-stack.md)).
- **Transcripts** — calls are saved to `~/voip-ada/transcripts/call-*.md` on hangup.
- **E2EE** — first run must cross‑sign and build the crypto‑store; see [docs/08](08-register-bind-gate.md).

Next: [docs/08 — Register, bind, gate](08-register-bind-gate.md).
