#!/usr/bin/env bash
# new-persona.sh — scaffold one persona: workspace + voip profile + systemd units.
#
#   ./scripts/new-persona.sh ada --port 8210 [--display "Ada Lovelace"] [--emoji "♾️"]
#
# Idempotent-ish: refuses to clobber an existing persona unless --force.
# Creates NO Matrix account and starts NO services — it only lays down files.
# Fill the .env secrets, register/bind/gate (docs/08), then enable the services.
set -euo pipefail

# ── args ──────────────────────────────────────────────────────────────────────
NAME="${1:-}"; shift || true
PORT=""; DISPLAY=""; EMOJI="🧠"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --port)    PORT="$2"; shift 2;;
    --display) DISPLAY="$2"; shift 2;;
    --emoji)   EMOJI="$2"; shift 2;;
    --force)   FORCE=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[ -n "$NAME" ] || { echo "usage: $0 <name> --port <N> [--display \"...\"] [--emoji X]" >&2; exit 2; }
[[ "$NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || { echo "name must be lowercase [a-z0-9_-]" >&2; exit 2; }
[ -n "$PORT" ] || { echo "--port <N> is required (unique per persona, e.g. 8210)" >&2; exit 2; }
[ -z "$DISPLAY" ] && DISPLAY="$(tr '[:lower:]' '[:upper:]' <<<"${NAME:0:1}")${NAME:1}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$REPO/templates"
WS="$HOME/.openclaw/workspace-$NAME"
VOIP="$HOME/voip-$NAME"
UNITS="$HOME/.config/systemd/user"

if [ -e "$WS" ] || [ -e "$VOIP" ]; then
  [ "$FORCE" = 1 ] || { echo "persona '$NAME' already exists (use --force to overwrite files)"; exit 1; }
fi

gen() { openssl rand -hex "${1:-32}"; }
sub() { sed -e "s/{{persona_id}}/$NAME/g" \
            -e "s/{{PERSONA_DISPLAY_NAME}}/$DISPLAY/g" \
            -e "s/{{API_PORT}}/$PORT/g"; }

echo "› scaffolding persona '$NAME' ($DISPLAY) on port $PORT"

# ── 1. workspace (persona files) ──────────────────────────────────────────────
mkdir -p "$WS/knowledge" "$WS/skills"
for f in SOUL IDENTITY USER TOOLS SAFETY HEARTBEAT AGENTS; do
  sub < "$TPL/persona/$f.md" > "$WS/$f.md"
done
echo "  ✓ $WS  (persona files — edit SOUL.md + IDENTITY.md)"

# ── 2. voip profile ───────────────────────────────────────────────────────────
mkdir -p "$VOIP/secrets" "$VOIP/crypto-store" "$VOIP/transcripts"
chmod 700 "$VOIP/secrets" "$VOIP/crypto-store"

APITOK="$(gen 32)"; CRYPTOPW="$(gen 24)"
sed -e "s/<name>/$NAME/g" \
    -e "s|/home/USER/|$HOME/|g" \
    -e "s/^API_PORT=.*/API_PORT=$PORT/" \
    -e "s/^API_TOKEN=.*/API_TOKEN=$APITOK/" \
    -e "s/^MATRIX_CRYPTO_STORE_PASSWORD=.*/MATRIX_CRYPTO_STORE_PASSWORD=$CRYPTOPW/" \
    "$TPL/voip/env.example" > "$VOIP/.env"
chmod 600 "$VOIP/.env"
echo "  ✓ $VOIP/.env  (API_TOKEN + crypto pw generated; fill MATRIX_ACCESS_TOKEN, hosts, voice)"

# per-agent PipeWire loopback scripts (isolated audio devices)
cat > "$VOIP/stt-loopback.sh" <<SH
#!/usr/bin/env bash
exec /usr/bin/pw-loopback \\
  --capture-props="media.class=Audio/Sink node.name=input.${NAME}_stt_speaker node.description=${NAME}-stt audio.position=[FL,FR]" \\
  --playback-props="media.class=Audio/Source node.name=${NAME}_stt_capture node.description=${NAME}-sttcap audio.position=[MONO]"
SH
cat > "$VOIP/tts-loopback.sh" <<SH
#!/usr/bin/env bash
exec /usr/bin/pw-loopback \\
  --capture-props="media.class=Audio/Sink node.name=input.${NAME}_tts node.description=${NAME}-tts audio.position=[FL,FR]" \\
  --playback-props="media.class=Audio/Source node.name=${NAME}_tts_mic node.description=${NAME}-ttscap audio.position=[MONO]"
SH
chmod +x "$VOIP/stt-loopback.sh" "$VOIP/tts-loopback.sh"
echo "  ✓ PipeWire loopback scripts (${NAME}_stt_*, ${NAME}_tts_*)"

# ── 3. systemd user units (concrete, per-persona) ─────────────────────────────
mkdir -p "$UNITS"
sed "s/%i/$NAME/g" "$TPL/systemd/voip-stt@.service"          > "$UNITS/$NAME-voip-stt.service"
sed "s/%i/$NAME/g" "$TPL/systemd/voip-tts@.service"          > "$UNITS/$NAME-voip-tts.service"
sed "s/%i/$NAME/g" "$TPL/systemd/matrix-voip-agent@.service" > "$UNITS/matrix-voip-agent-$NAME.service"
echo "  ✓ systemd units: $NAME-voip-stt, $NAME-voip-tts, matrix-voip-agent-$NAME"

# ── next steps ────────────────────────────────────────────────────────────────
cat <<NEXT

Persona '$NAME' scaffolded. Next:
  1. Write personality:   \$EDITOR $WS/SOUL.md  $WS/IDENTITY.md
  2. Voice (docs/06):     set VOXTRAL_TTS_MODE + voice in $VOIP/.env
  3. Matrix acct (docs/08): create @$NAME:matrix.example.com, put its token in $VOIP/.env
  4. Register + gate:
       openclaw agents add $NAME --workspace $WS --model vllm/qwen36-deep \\
         --identity-name "$DISPLAY" --identity-emoji "$EMOJI"
       echo '{"allowFrom":["@you:matrix.example.com"]}' > ~/.openclaw/credentials/matrix-$NAME-allowFrom.json
       openclaw gateway restart
  5. Start the call line:
       systemctl --user daemon-reload
       systemctl --user enable --now $NAME-voip-stt $NAME-voip-tts matrix-voip-agent-$NAME

API port $PORT · API token + crypto pw were generated into $VOIP/.env (mode 600).
NEXT
