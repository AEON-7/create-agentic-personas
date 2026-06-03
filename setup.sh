#!/usr/bin/env bash
# setup.sh — first-time validation for create-agentic-personas.
#
# This repo is a GUIDE + scaffold, not a runtime app, so "setup" doesn't install a
# service — it verifies the SHARED infrastructure a persona needs is reachable and the
# tools `scripts/new-persona.sh` calls are present, then prints how to fix anything
# missing. Run it on the box where your agents/voip will live (AGENT_HOST).
#
#   ./setup.sh                                  # checks local tools only
#   ./setup.sh --infer-host 10.0.0.10           # also probe vLLM/ASR/TTS on that host
#   INFER_HOST=10.0.0.10 ./setup.sh             # same, via env
#   ./setup.sh --infer-host h --homeserver http://127.0.0.1:8008
#
# Non-zero exit only if a REQUIRED local tool is missing; infra checks are warnings,
# since you may run this before standing the backend up (see docs/01-03).
set -uo pipefail

INFER_HOST="${INFER_HOST:-}"
HS_URL="${MATRIX_HOMESERVER_URL:-http://127.0.0.1:8008}"
while [ $# -gt 0 ]; do
  case "$1" in
    --infer-host) INFER_HOST="$2"; shift 2;;
    --homeserver) HS_URL="$2"; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

pass=0; warn=0; fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
note() { printf '  \033[33m⚠\033[0m %s\n' "$1"; warn=$((warn+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }

have() { command -v "$1" >/dev/null 2>&1; }
probe() { curl -fsS -m 5 "$1" >/dev/null 2>&1; }

echo "create-agentic-personas — setup check"
echo

echo "Required (this repo's scaffold scripts):"
for t in git openssl curl sed; do
  have "$t" && ok "$t" || bad "$t missing — install it (brew/apt install $t)"
done

echo
echo "Agent-host tools (needed to RUN personas; warn-only if you're on a different box):"
have node       && ok "node ($(node -v 2>/dev/null))"          || note "node missing — needed by matrix-voip-agent (nodejs.org or nvm)"
have systemctl  && ok "systemd (systemctl present)"            || note "systemctl missing — per-agent services use systemd --user"
have pw-loopback&& ok "pipewire (pw-loopback present)"         || note "pw-loopback missing — install pipewire (per-agent audio isolation)"
have openclaw   && ok "openclaw CLI"                           || note "openclaw missing — the gateway/agent manager (see docs/01)"
if have systemctl; then
  systemctl --user is-active pipewire >/dev/null 2>&1 && ok "pipewire user session active" \
    || note "pipewire user session not active — needed for calls"
fi

echo
echo "Shared infrastructure:"
if [ -n "$INFER_HOST" ]; then
  probe "http://$INFER_HOST:8000/v1/models" && ok "LLM  vLLM   http://$INFER_HOST:8000" || note "LLM  unreachable at http://$INFER_HOST:8000 (docs/01)"
  probe "http://$INFER_HOST:8001/v1/models" && ok "STT  ASR    http://$INFER_HOST:8001" || note "STT  unreachable at http://$INFER_HOST:8001 (docs/01)"
  probe "http://$INFER_HOST:8002/v1/models" && ok "TTS  voice  http://$INFER_HOST:8002" || note "TTS  unreachable at http://$INFER_HOST:8002 (docs/01)"
else
  note "no --infer-host given — skipping vLLM/ASR/TTS probes (pass --infer-host to test)"
fi
probe "$HS_URL/_matrix/client/versions" && ok "Matrix homeserver  $HS_URL" || note "homeserver unreachable at $HS_URL (docs/02)"

echo
echo "Repo:"
[ -x scripts/new-persona.sh ] && ok "scripts/new-persona.sh executable" || note "run: chmod +x scripts/*.sh setup.sh sync.sh"
[ -f templates/voip/env.example ] && ok "templates present" || bad "templates/ missing — repo incomplete"

echo
echo "── $pass ok · $warn warning(s) · $fail failure(s) ──"
if [ "$fail" -gt 0 ]; then
  echo "Fix the ✗ items, then re-run ./setup.sh"
  exit 1
fi
echo "Ready. Next: ./scripts/new-persona.sh <name> --port <N>   (then see AGENTS.md)"
[ "$warn" -gt 0 ] && echo "(Warnings are fine if the backend isn't up yet — see docs/01-03.)"
exit 0
