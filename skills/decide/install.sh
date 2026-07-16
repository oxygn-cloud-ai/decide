#!/usr/bin/env bash
# install.sh — Claude Code CLI installer for /decide
# Copies the skill into your Claude skills directory with correct modes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET="${CLAUDE_DIR}/skills/decide"

# Refuse to write through a symlink planted at the target (local-attacker hardening).
for p in "$TARGET" "$TARGET/references" "$TARGET/SKILL.md" "$TARGET/record-template.md" \
         "$TARGET/references/challenger.sh" "$TARGET/references/adjudicator.sh"; do
  [ -L "$p" ] && { echo "ERROR: refusing to install — '$p' is a symlink. Remove it and re-run." >&2; exit 1; }
done

mkdir -p "$TARGET/references"
# install (not cp+chmod glob): sets exact modes on exact files only.
install -m 644 "$SCRIPT_DIR/SKILL.md"                       "$TARGET/SKILL.md"
install -m 644 "$SCRIPT_DIR/record-template.md"            "$TARGET/record-template.md"
install -m 755 "$SCRIPT_DIR/references/challenger.sh"      "$TARGET/references/challenger.sh"
install -m 755 "$SCRIPT_DIR/references/adjudicator.sh"     "$TARGET/references/adjudicator.sh"

echo "✓ /decide installed to $TARGET"
if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "  NOTE: set an OpenAI-compatible key to enable the cross-model Challenger/Adjudicator:"
  echo "        export OPENAI_API_KEY=\"sk-...\"                          # OpenAI (default)"
  echo "        # or another provider:  export OPENAI_BASE_URL=https://api.deepseek.com/v1 CHALLENGER_MODEL=deepseek-chat"
fi
echo "  Restart Claude Code, then run:  /decide <the decision you're facing>"
