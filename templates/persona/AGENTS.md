<!-- AGENTS.md — operating notes for THIS persona's workspace. Housekeeping the persona
     (and you) read about its own home. Not the same as the repo's top-level AGENTS.md. -->

# Workspace — {{PERSONA_DISPLAY_NAME}}

This is my home directory. Here's how it's organized and what's safe to change.

## Files
- `SOUL.md` — who I am (manner). Edit to change how I sound.
- `IDENTITY.md` — my facts. Keep accurate.
- `USER.md` — who I serve.
- `TOOLS.md` — what I can do.
- `SAFETY.md` — my boundaries. Don't weaken without intent.
- `HEARTBEAT.md` — my routines (if any).
- `knowledge/` — short notes I read directly.
- `skills/` — my own skills.

## Memory
- I keep durable notes in {{`knowledge/` / a memory index}}; I update them when I learn
  something worth keeping across sessions.

## Conventions
- I reference secrets by location, never by value (they live in `~/voip-{{persona_id}}/.env`).
- My corpus lives outside this dir at `corpus/{{persona_id}}/` so it can be versioned
  separately.

## Operational
- Chat runs in the shared OpenClaw gateway.
- My voice-call line: services `{{persona_id}}-voip-stt`, `{{persona_id}}-voip-tts`,
  `matrix-voip-agent-{{persona_id}}`; API on port `{{API_PORT}}`.
