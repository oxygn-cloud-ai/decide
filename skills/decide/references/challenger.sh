#!/usr/bin/env bash
# challenger.sh — the cross-model Challenger for /decide.
# Sends the assembled CASE FILE to a DIFFERENT model family and asks it to build the strongest case
# the human is WRONG, using their own disclosed facts. Emits a JSON array of objections on stdout.
#
# Usage: challenger.sh <case-file>
# Env:   OPENAI_API_KEY (required). CHALLENGER_MODEL (default gpt-5.6).
#        OPENAI_BASE_URL (default https://api.openai.com/v1) — any OpenAI-compatible endpoint; MUST be
#        https:// (set DECIDE_ALLOW_INSECURE_BASE_URL=1 to allow http://localhost for local testing).
# Exit 0 = valid objections on stdout. Exit 1 = failure. On failure the interviewer must NOT fall back
#          to self-dissent — one model grading its own reasoning is the failure mode /decide prevents.
set -euo pipefail
umask 077   # temp files (incl. the API-key auth header) are created user-only

command -v jq   >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }

CASE="${1:-}"
[ -z "$CASE" ]  && { echo "ERROR: usage: challenger.sh <case-file>" >&2; exit 1; }
[ ! -f "$CASE" ] || [ ! -s "$CASE" ] && { echo "ERROR: case file missing or empty: $CASE" >&2; exit 1; }

# Input size cap (a case file is short interview notes; refuse to upload a huge transcript).
MAX_INPUT=${DECIDE_MAX_INPUT_BYTES:-262144}
SIZE=$(wc -c < "$CASE")
[ "$SIZE" -gt "$MAX_INPUT" ] && { echo "ERROR: case file is $SIZE bytes (> $MAX_INPUT). Trim it to the load-bearing facts." >&2; exit 1; }

[ -z "${OPENAI_API_KEY:-}" ] && { echo "ERROR: OPENAI_API_KEY not set — the cross-model Challenger cannot run. Set it and re-run. Do NOT self-dissent." >&2; exit 1; }

MODEL="${CHALLENGER_MODEL:-gpt-5.6}"
BASE="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
# Refuse to send the API key + private case data over an unencrypted or malformed URL. This blocks a
# poisoned OPENAI_BASE_URL from exfiltrating your key/data over http:// to an arbitrary host.
case "$BASE" in
  https://*) : ;;
  http://localhost*|http://127.0.0.1*)
    [ "${DECIDE_ALLOW_INSECURE_BASE_URL:-}" = "1" ] || { echo "ERROR: refusing http:// base URL. For local testing set DECIDE_ALLOW_INSECURE_BASE_URL=1." >&2; exit 1; } ;;
  *) echo "ERROR: OPENAI_BASE_URL must be https:// (got '${BASE}'). Refusing to send your API key over an unencrypted or malformed URL." >&2; exit 1 ;;
esac

CONTENT=$(cat "$CASE")

SYSTEM='You are the CHALLENGER in a decision interview. A human has stated a lean on a high-stakes, hard-to-reverse decision, and a different model has interviewed them. Your ONLY job is to build the strongest possible case that the human is WRONG — using their OWN stated reasoning, their base rates, and the private facts they disclosed. You do not resolve, soften, hedge, or find middle ground. You attack. Another model will adjudicate whether the human answers you; that is not your concern.

Produce a JSON array of 3-6 OBJECTIONS, each the sharpest version of a distinct way the decision is wrong. For each: {"id":"O1","claim":"one sentence: the flaw in their reasoning","why_it_bites":"2-3 sentences using THEIR specific facts/numbers — not generic skepticism","what_would_settle_it":"the concrete evidence or test that would show the human right or wrong","severity":"FATAL|MAJOR|MINOR"}.

Rules: use the human''s OWN numbers and disclosed facts against them; generic "have you considered risk?" is worthless. At least one objection must challenge the PREMISE/framing itself. If their private facts actually support a DIFFERENT decision than their lean, say so explicitly as an objection. Do NOT invent facts — if you need one, phrase it as "if [fact], then…" and put it in what_would_settle_it. Rank FATAL first; do not pad with MINOR objections. Return ONLY the JSON array.'

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT HUP INT TERM     # cleanup on normal exit AND signals (SIGKILL excepted)
HDR="$TMPD/hdr"; PAY="$TMPD/pay"; BODY="$TMPD/body"
printf 'Authorization: Bearer %s\n' "$OPENAI_API_KEY" > "$HDR"   # key via file (0600 dir), not argv/ps
jq -n --arg s "$SYSTEM" --arg c "$CONTENT" --arg m "$MODEL" \
  '{model:$m, messages:[{role:"system",content:$s},{role:"user",content:("CASE FILE:\n\n"+$c)}], max_completion_tokens:8000}' > "$PAY"

CODE=000
for attempt in 1 2 3; do
  CODE=$(curl -sS --max-time 180 --max-filesize 20000000 -w '%{http_code}' -o "$BODY" \
    -H "Content-Type: application/json" -H "@${HDR}" -d "@${PAY}" \
    "${BASE}/chat/completions" 2>/dev/null || echo 000)
  if [ "$CODE" = "200" ]; then
    # Extract the model content, strip any ```json fences, and require a NON-EMPTY JSON ARRAY.
    # A 200 with empty content, an {"error":...} body, or non-array output is NOT a valid result —
    # otherwise the cross-model check would silently vanish.
    RAW=$(jq -r '.choices[0].message.content // empty' "$BODY" 2>/dev/null || true)
    CLEAN=$(printf '%s' "$RAW" | sed -e 's/^[[:space:]]*```json[[:space:]]*//' -e 's/^[[:space:]]*```[[:space:]]*//' -e 's/[[:space:]]*```[[:space:]]*$//')
    if [ -n "$CLEAN" ] && printf '%s' "$CLEAN" | jq -e 'type=="array" and length>0' >/dev/null 2>&1; then
      printf '%s\n' "$CLEAN"
      exit 0
    fi
    echo "WARN: 200 response but no valid objections array (empty/error/non-JSON) — attempt $attempt." >&2
  fi
  [ "$attempt" -lt 3 ] && sleep $((attempt * 2))
done
echo "ERROR: Challenger produced no valid objections (last HTTP $CODE) after 3 attempts. Cross-model step FAILED — do not self-dissent." >&2
exit 1
