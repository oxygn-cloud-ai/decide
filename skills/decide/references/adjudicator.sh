#!/usr/bin/env bash
# adjudicator.sh — the neutral Adjudicator for /decide.
# Sends {objection, human_rebuttal} pairs to a model that is NOT the interviewer, and asks whether
# each rebuttal actually ANSWERED the objection. Emits a JSON array of verdicts on stdout. Must not be
# the same model instance that ran the interview: a synthesizer grading its own challenges defeats it.
#
# Usage: adjudicator.sh <pairs-file>   (JSON array: [{"id","objection","rebuttal"},...])
# Env:   OPENAI_API_KEY (required). ADJUDICATOR_MODEL (default gpt-5.6).
#        ADJUDICATOR_BASE_URL / OPENAI_BASE_URL (default https://api.openai.com/v1) — https:// only
#        (DECIDE_ALLOW_INSECURE_BASE_URL=1 permits http://localhost). Point at a DIFFERENT provider
#        than the Challenger for maximum independence.
# Exit 0 = valid verdicts on stdout. Exit 1 = failure.
set -euo pipefail
umask 077

command -v jq   >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }

PAIRS="${1:-}"
[ -z "$PAIRS" ]  && { echo "ERROR: usage: adjudicator.sh <pairs-file>" >&2; exit 1; }
[ ! -f "$PAIRS" ] || [ ! -s "$PAIRS" ] && { echo "ERROR: pairs file missing or empty: $PAIRS" >&2; exit 1; }
jq empty "$PAIRS" 2>/dev/null || { echo "ERROR: pairs file is not valid JSON" >&2; exit 1; }

MAX_INPUT=${DECIDE_MAX_INPUT_BYTES:-262144}
SIZE=$(wc -c < "$PAIRS")
[ "$SIZE" -gt "$MAX_INPUT" ] && { echo "ERROR: pairs file is $SIZE bytes (> $MAX_INPUT)." >&2; exit 1; }

[ -z "${OPENAI_API_KEY:-}" ] && { echo "ERROR: OPENAI_API_KEY not set — the Adjudicator cannot run." >&2; exit 1; }

MODEL="${ADJUDICATOR_MODEL:-gpt-5.6}"
BASE="${ADJUDICATOR_BASE_URL:-${OPENAI_BASE_URL:-https://api.openai.com/v1}}"
case "$BASE" in
  https://*) : ;;
  http://localhost*|http://127.0.0.1*)
    [ "${DECIDE_ALLOW_INSECURE_BASE_URL:-}" = "1" ] || { echo "ERROR: refusing http:// base URL. For local testing set DECIDE_ALLOW_INSECURE_BASE_URL=1." >&2; exit 1; } ;;
  *) echo "ERROR: adjudicator base URL must be https:// (got '${BASE}'). Refusing to send your API key over an unencrypted or malformed URL." >&2; exit 1 ;;
esac

CONTENT=$(cat "$PAIRS")

SYSTEM='You adjudicate whether a human'\''s rebuttal actually answered a Challenger objection. You are neutral — you do not want the human to be right or wrong; you enforce an evidentiary standard. The model that ran the interview is NOT allowed to do this job because it is motivated to be agreeable.

For each {id, objection, rebuttal}, return {"id":"O1","verdict":"ADDRESSED|UNADDRESSED|CONCEDED_WITHOUT_REASON","reason":"one line"}.

Standards:
- ADDRESSED — the rebuttal engages the SPECIFIC flaw with evidence, a disclosed fact, or a sound argument meeting what the objection asked for. Restating the lean, expressing confidence, or an emotional/motivational reply ("the team is resilient", "I trust them") is NOT enough. If the objection needed a number or fact and the human gave neither, it is UNADDRESSED.
- UNADDRESSED — the rebuttal dodges, restates the position, answers a different question, or asserts without the evidence the objection specifically asked for.
- CONCEDED_WITHOUT_REASON — the human simply agreed / dropped the lean WITHOUT stating an evidence-based reason. This does NOT resolve the objection (it may be coerced capitulation, not a genuine update) — flag it.

Be strict and symmetric: the same bar whether the rebuttal defends or abandons the lean. A confident-sounding but evidence-free answer is UNADDRESSED regardless of which side it favors. Return ONLY the JSON array of verdicts.'

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT HUP INT TERM
HDR="$TMPD/hdr"; PAY="$TMPD/pay"; BODY="$TMPD/body"
printf 'Authorization: Bearer %s\n' "$OPENAI_API_KEY" > "$HDR"
jq -n --arg s "$SYSTEM" --arg c "$CONTENT" --arg m "$MODEL" \
  '{model:$m, messages:[{role:"system",content:$s},{role:"user",content:("Adjudicate each pair:\n\n"+$c)}], max_completion_tokens:4000}' > "$PAY"

CODE=000
for attempt in 1 2 3; do
  CODE=$(curl -sS --max-time 120 --max-filesize 20000000 -w '%{http_code}' -o "$BODY" \
    -H "Content-Type: application/json" -H "@${HDR}" -d "@${PAY}" \
    "${BASE}/chat/completions" 2>/dev/null || echo 000)
  if [ "$CODE" = "200" ]; then
    RAW=$(jq -r '.choices[0].message.content // empty' "$BODY" 2>/dev/null || true)
    CLEAN=$(printf '%s' "$RAW" | sed -e 's/^[[:space:]]*```json[[:space:]]*//' -e 's/^[[:space:]]*```[[:space:]]*//' -e 's/[[:space:]]*```[[:space:]]*$//')
    if [ -n "$CLEAN" ] && printf '%s' "$CLEAN" | jq -e 'type=="array" and length>0' >/dev/null 2>&1; then
      printf '%s\n' "$CLEAN"
      exit 0
    fi
    echo "WARN: 200 response but no valid verdicts array — attempt $attempt." >&2
  fi
  [ "$attempt" -lt 3 ] && sleep $((attempt * 2))
done
echo "ERROR: Adjudicator produced no valid verdicts (last HTTP $CODE) after 3 attempts." >&2
exit 1
