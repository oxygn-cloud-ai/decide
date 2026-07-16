---
name: decide
version: 1.0.2
description: Katabasis Decision Interview — a structured human+AI process for high-stakes, hard-to-reverse decisions. It interviews YOU, then a DIFFERENT model family attacks your reasoning and adjudicates whether your answers held, with anti-coercion safeguards. Use for consequential decisions where being wrong is expensive. Needs an OpenAI-compatible API key (OpenAI, DeepSeek, Together, …) for the cross-model step. Accepts /decide <the decision you're facing>.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, WebSearch, AskUserQuestion
argument-hint: "[the decision you're facing]"
---

# `/decide` — the Katabasis Decision Interview

**What this is — and is NOT.** This does NOT write you an assessment. It interviews *you*, then turns a
genuinely **different model family** loose on your reasoning and has it adjudicate whether your answers
held. The value is not a better memo (a frontier model already writes those); it is **overriding your
own bias and the model's default agreeableness** on a decision that matters.

**Use it only for** consequential, hard-to-reverse decisions where being wrong is expensive. It costs
you 30–60 minutes of real engagement. It is the wrong tool for quick or low-stakes calls.

**Privacy:** the cross-model step sends your decision, reasoning, and the facts you disclose to the
OpenAI API. Don't run it on secrets/PII you can't share with a third-party API.

## The engine — three roles, and they must NOT be the same model
- **Interviewer/Synthesizer** = you, the assistant running this skill (Claude).
- **Challenger** = a DIFFERENT model family, via `references/challenger.sh` (OpenAI). Its only job is to
  attack the human's reasoning. Never resolves or softens.
- **Adjudicator** = `references/adjudicator.sh` — marks each objection ADDRESSED / UNADDRESSED /
  CONCEDED_WITHOUT_REASON against an evidentiary standard. The interviewer may NEVER grade its own
  challenges.
The scripts call any **OpenAI-compatible** endpoint: set `OPENAI_API_KEY`, and optionally
`OPENAI_BASE_URL` + `CHALLENGER_MODEL` to use a provider other than OpenAI (e.g.
`OPENAI_BASE_URL=https://api.deepseek.com/v1 CHALLENGER_MODEL=deepseek-chat`). Pick a family
*different from you (Claude)* so the dissent is genuinely cross-model.

If the key is unset or the script fails, STOP and tell the user the cross-model step cannot run. Do
NOT fall back to attacking your own draft — a single model role-playing dissent against itself
*bolsters* the original view (it does not diverge); that is the failure mode this tool exists to avoid.

## Anti-coercion safeguards (enforced throughout)
1. Unresolved objections **cap** the final confidence (process length can never inflate it).
2. A concession counts as a genuine update ONLY if the human states *why* (evidence). Bare
   capitulation is recorded as "conceded without reason" and does NOT resolve the objection.
3. Any reframe the Challenger introduces is itself evidence-backed and adjudicated — do not talk the
   human into a slick-but-unsupported new framing.
4. The output states plainly: **process completeness is not truth.** It shows what was NOT resolved.
5. Withhold-endorsement is a valid, expected outcome. If material objections stand, do NOT recommend.

## The interview

### Phase 0 — Frame & surface the lean
Ask: What exactly are you deciding? Stakes? How reversible? Deadline? **What's your current lean, and
what is it resting on?** Do not proceed without an explicit lean — it is what gets attacked. Create a
`decide_<slug>/` folder and record Phase 0.

### Phase 1 — Attack the premise
Invert their framing. "You're deciding X — what if the real question is Y? Whose interest does your
framing serve? What are you assuming that, if false, flips this?" The human must answer.

### Phase 2 — Run the operations ON the human (each gated by a required artifact)
- **Outside view:** establish the reference class; state the base rate (WebSearch if useful). "Does
  your lean survive it?"
- **Premortem:** "It's a year on and this failed. *You* name the top cause."
- **Circle of competence:** "Mark each key judgment — do you know this, or are you guessing?" Guesses
  become risks, not facts.
- **Bias interrupt:** reflect their own emphasis back ("upside 3×, downside 1×") — anchor or real?

### Phase 3 — Extract the private context the model cannot have — ADAPTIVELY (make-or-break)
People hold back what's most damaging; a scripted interview misses the decisive facts. So dig:
- **Never accept a non-answer** ("cultural fit", "it's complicated") — chase the specific reason.
- **Probe every number** for the fact behind it (concentration, trend, source, what's excluded).
- **Follow every emotional tell** (hesitation, a changed subject, "honestly", "I've been avoiding").
- **Always ask:** (a) who else is materially affected, and have they *informedly* agreed? (b) what is
  your best ALTERNATIVE if this option vanished? (the dominant alternative is the most-often-hidden
  fact) (c) what is the one fact you'd least like me to know?
- **Pull each thread to exhaustion**, then name the remaining gaps out loud and ask directly.

### Phase 4 — Cross-model dissent + adjudication (the engine)
1. Write the **case file** to `decide_<slug>/case.md`: the decision, the lean + reasoning, the Phase-2
   artifacts, the Phase-3 private facts.
2. Run: `bash references/challenger.sh decide_<slug>/case.md` → objections JSON. Present each to the
   human and require a **specific** rebuttal (not a hand-wave).
3. Write `decide_<slug>/pairs.json` as `[{"id","objection","rebuttal"},…]` and run:
   `bash references/adjudicator.sh decide_<slug>/pairs.json` → verdicts. Do NOT overrule it.
4. Loop any UNADDRESSED objection back to the human once more, then freeze the ledger.

### Phase 5 — Decide (with the safeguards)
- The human states the decision **in their own words** + a confidence that is **capped** by the number
  and severity of unresolved objections.
- Write `decide_<slug>/RECORD.md` (see `record-template.md`): decision, tested premises, base rates,
  premortem, the full objection ledger, residual uncertainty, what would change the answer, and the
  "process completeness ≠ truth" note.
- If material objections remain UNADDRESSED, **withhold** the recommendation: report "not resolved —
  here is what you still need," not a decision.

## Honest limits (tell the user)
- The mechanism (cross-model dissent + neutral adjudication aimed at your reasoning) is validated; that
  it beats a strong adversarial chat *for real humans without badgering them into overconfidence* is
  still an open question — treat the output as a rigorous stress-test, not an oracle.
- Its value is largest for the decider who would otherwise get agreement from a plain chat.
- For maximum independence, point the Adjudicator at a different provider than the Challenger
  (`ADJUDICATOR_MODEL` / a second key).
