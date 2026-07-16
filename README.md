# `/decide` — the Katabasis Decision Interview

**Make your hardest calls without fooling yourself.** `/decide` doesn't write you an answer — it
**interviews you**, then turns a *different AI model* loose on your reasoning and has a neutral third
step adjudicate whether your answers actually held. It's built to beat the two things that wreck
high-stakes decisions: **your own bias**, and an AI's **default agreeableness**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Desktop](https://img.shields.io/badge/Platform-Claude_Desktop-d97706)](https://claude.ai/download)
[![Claude Code CLI](https://img.shields.io/badge/Platform-Claude_Code_CLI-2563eb)](https://docs.anthropic.com/en/docs/claude-code/overview)

---

## Why `/decide`?

Ask an AI "should I take this offer?" and it mostly *agrees with you* — it mirrors your framing and
softens the hard parts. And when you reason alone, you anchor on the exciting number and quietly bury
the facts that cut against what you already want.

`/decide` is engineered against both. A frontier model **interviews you** and adaptively digs out the
private facts you're holding back. Then a **genuinely different model family** attacks your reasoning
using *your own disclosed facts* — and a **neutral adjudicator** refuses to let "I trust them" or "I'm
just tired" count as an answer. You leave with a decision you actually stress-tested, a record of what
survived and what didn't, and a confidence level that's **capped by what you couldn't resolve**.

> **Why a *different* model matters:** a single model told to "play devil's advocate" against its own
> draft tends to *reinforce* the original view, not diverge from it (Nemeth, 2001). Genuine dissent
> needs a genuinely different mind. That is this tool's entire engine.

---

## What a session produces

- An **adaptive interview** that pulls out the load-bearing facts — including the ones you'd rather not
  say (the dominant alternative you've dismissed, who hasn't really consented, the number you've been
  avoiding).
- A **cross-model challenge**: 3–6 sharp objections built from *your* facts, ranked FATAL → MINOR.
- A **neutral adjudication**: each of your rebuttals marked ADDRESSED / UNADDRESSED /
  CONCEDED-WITHOUT-REASON — so a confident-sounding non-answer doesn't slip through.
- A **decision record** with the objection ledger, what would change your mind, residual uncertainty,
  and a confidence capped by unresolved objections. If too much stands unresolved, it **withholds** a
  recommendation and tells you what to go find out.

---

## Which one should I install?

| You use… | Install | How |
|----------|---------|-----|
| **Claude Desktop** (the app) | download `decide.zip` | unzip into `~/.claude/skills/decide/` |
| **Claude Code CLI** (the terminal) | clone + `install.sh` | one command |

Same engine either way. Both need an **OpenAI-compatible API key** for the cross-model
Challenger/Adjudicator — **OpenAI, DeepSeek, Together, Groq, or a local server** all work (set
`OPENAI_BASE_URL` + `CHALLENGER_MODEL` for non-OpenAI providers).

---

## Quick Start

### Claude Desktop
1. Download `decide.zip` from the [latest release](https://github.com/oxygn-cloud-ai/decide/releases).
2. Unzip its contents into `~/.claude/skills/decide/`.
3. `chmod +x ~/.claude/skills/decide/references/*.sh`
4. Set your key: `export OPENAI_API_KEY="sk-..."` (in your shell profile).
5. Restart Claude Desktop.
6. Type: **"run /decide on whether I should <your decision>"**

### Claude Code CLI
```bash
git clone https://github.com/oxygn-cloud-ai/decide.git
cd decide/skills/decide && bash install.sh
export OPENAI_API_KEY="sk-..."     # enables the cross-model step
# restart Claude Code, then:
/decide should I accept the acquisition offer?
```

---

## How it works (three roles, three separate models)

1. **Interviewer** (Claude, running the skill) — frames the decision, attacks your premise, runs the
   outside-view/premortem/competence checks *on you*, and adaptively extracts your private context.
2. **Challenger** (`references/challenger.sh` → OpenAI) — a different model family builds the strongest
   case you're wrong, using your own facts. It only attacks.
3. **Adjudicator** (`references/adjudicator.sh` → OpenAI, separate call) — marks whether each rebuttal
   truly answered the objection. The interviewer never grades its own challenges.

**Any OpenAI-compatible provider works** (OpenAI, DeepSeek, Together, Groq, local). Use OpenAI by
default, or point elsewhere:

```bash
export OPENAI_API_KEY="sk-..."                      # OpenAI (default), model gpt-5.6
# — or any compatible endpoint —
export OPENAI_BASE_URL="https://api.deepseek.com/v1"
export CHALLENGER_MODEL="deepseek-chat"
```

For maximum independence, point the Adjudicator at a *different provider* than the Challenger
(`ADJUDICATOR_BASE_URL` / `ADJUDICATOR_MODEL`). Just make sure the Challenger family is **different
from Claude**, or the dissent isn't cross-model.

If the key is missing, the tool stops and says so — it will **not** fake dissent by arguing with
itself, because that's the failure mode it exists to prevent.

> The engine (challenger + adjudicator scripts) is verified end-to-end against a live
> OpenAI-compatible API: the challenger produces grounded objections from your facts, and the
> adjudicator correctly marks evidence-free rebuttals UNADDRESSED while accepting reasoned updates.

---

## Privacy

The cross-model step **uploads your decision, reasoning, and the facts you disclose** to the API
provider over HTTPS. Do not run `/decide` on secrets, credentials, PII, or proprietary information you
cannot share with a third-party API.

**Security posture** (the scripts were adversarially reviewed):
- Your API key is passed to `curl` via a temp file (`umask 077`, `chmod 600`) — never in a command
  line or process list — and cleaned up on exit/signal.
- The endpoint **must be `https://`** — the scripts refuse a plaintext/malformed `OPENAI_BASE_URL`, so a
  poisoned environment can't exfiltrate your key or data over `http://`.
- Content and env are inserted via `jq --arg` (no injection); input size is capped; a `200` response
  with empty/invalid output is treated as a failure, not a silent pass.
- No telemetry, no analytics, no credentials in the repo.

## Honest limits

The *mechanism* — cross-model dissent + neutral adjudication aimed at your reasoning — is validated.
Whether it beats a strong adversarial chat **for real people, without badgering them into
overconfidence**, is an open question we're actively studying. Treat `/decide` as a rigorous
stress-test that makes your own biases expensive to keep — not an oracle. It's for consequential,
hard-to-reverse decisions; it's the wrong tool for quick ones.

## License
MIT © Oxygn Pte Ltd
