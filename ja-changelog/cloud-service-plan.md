# Cloud Changelog Service — Design & Plan

**Status: PLANNED — not yet implemented.** Deliberately on hold as of 2026-07-13; captured here so
we can pick it up later. This describes a webhook-triggered cloud service that does what the
`ja-changelog` skill does today (manually), as deterministically as possible, using the LLM **only**
for the non-deterministic parts: interpreting code/commits and writing the changelog prose.

## Core principle: the LLM is a pure, cached function

Draw a hard wall around the model. It is a pure function with **no** authority over *what* shipped,
*whether* to publish, or *where*:

```
interpret(ReleaseFacts) -> ChangelogBullets      // temperature 0, schema-locked, memoized by hash(ReleaseFacts + promptVersion + modelVersion)
```

It never calls tools, never decides scope, never touches Slack. It receives a fully-assembled
structured fact bundle and returns structured bullets. Everything before and after is deterministic
code. That single boundary is what buys determinism.

## 1. Triggers (ingress)

| Source | Event | Notes |
|--------|-------|-------|
| EDL / SIGEM / Gabinete | GitHub `release` webhook, `action=published` | Drop `draft`/`prerelease` at the door |
| App JA | GitHub `workflow_run` webhook (deploy workflow) **+** scheduled App Store poller (cron) | The App Store is the gate, not the pipeline — same rule the skill already encodes |

Webhook receiver does nothing but verify the HMAC signature, dedupe on `X-GitHub-Delivery`, and
enqueue. All real work runs in an idempotent worker off the queue (at-least-once delivery ⇒
idempotency is mandatory).

## 2. Deterministic collection (port `collect_app_changes.py` verbatim)

Already pure — the crown jewel. Given a repo + previous published tag, it computes
`prevPublished..thisTag`, resolves merged PRs, commits, and changed-file statuses. Wrap it as a
library the worker calls. Emit a canonical **`ReleaseFacts`** record:

```jsonc
{
  "app": "EDL", "tag": "v2.287.1", "publishedAt": "2026-07-09",
  "compareRange": "v2.281.5..v2.287.1",
  "prs": [...], "commits": [...],
  "changedFiles": [{"status":"A","path":"...StationHistoryModal.tsx"}],
  "clickupCandidates": [{"prPrefix":"MON","task":{...},"score":0.82}]
}
```

ClickUp matching stays **deterministic** (prefix + fuzzy title score) and is fed to the LLM as
*candidates*, not resolved for it — code proposes matches, the LLM picks the framing.

## 3. State store = source of truth

A database (DynamoDB or Postgres) sits between everything. Per app it records: last documented
version, and **every changelog entry as structured data** (category, bullets, date, status). Per
release: `hash(ReleaseFacts)`, `hash(bullets)`, publish state, Slack message ids.

**Consequence:** "what's already documented" comes from the DB, not by re-reading the canvas. The
canvas becomes a **projection** rendered *from* the DB — which removes the fragile
read-canvas → `render_canvas.py --extract` → re-render round trip the skill fights today. The canvas
is regenerated as a pure function of DB state, every time.

## 4. The LLM step — as deterministic as an LLM gets

- **Structured output / tool-use schema** forces valid JSON; validate + retry on mismatch.
- **Temperature 0**, **pinned model version** (`claude-opus-4-8`, not a floating alias), **frozen,
  versioned prompt**.
- **Memoize on `hash(ReleaseFacts + promptVersion + modelVersion)`** — same input ⇒ cached output, so
  webhook replays, retries, and re-runs are byte-identical. The cache is the determinism.
- Honest ceiling: temp 0 is not *guaranteed* reproducible across model releases — hence pinning +
  caching. When the model is deliberately bumped, treat regenerated bullets as a **diff to review**,
  never a silent overwrite.

## 5. Deterministic render + publish

- `bullets (JSON) → Spanish markdown` via templates (voice + emoji rules become code, not vibes).
- Canvas: `renderCanvas(all entries from DB) → full body`, then the safe `replace`-without-section_id
  + `prepend` sequence. Pure function of DB state.
- Slack notice: template from the same bullets (bullets inline, no canvas link).

## 6. Per-release state machine (esp. App JA)

```
detected → facts_collected → bullets_generated → [approval?] → published → notified
                                                       ↑
App JA adds:   announced → deployed → store_live ──────┘   (only store_live advances)
```

The `Pendiente` logic is just this state machine — no LLM in the gating.

## 7. Optional human-in-the-loop

Since it's client/PO-facing, add one gate: post the rendered draft to a **private** approval channel
and promote to the client canvas only on a 👍 reaction (a reaction webhook flips the state). Keeps a
human between the LLM and the audience without reintroducing manual work.

## 8. Suggested stack

Fit into the existing **AWS + CDK** setup (EDL already has `cdk/` and an `ErliaDisasterRecoveryComponent`):

- **API Gateway → Lambda** (verify + enqueue) → **SQS** → **Lambda worker**
- **DynamoDB** (state), **Secrets Manager** (GitHub/ClickUp/Slack/Anthropic keys), **EventBridge**
  (App Store poll)
- Anthropic API for the single `interpret` call
- Everything else is the existing Python collector + deterministic renderers

## 9. What stays LLM vs code

| Deterministic (code) | Non-deterministic (LLM, temp 0 + cached) |
|---|---|
| Detect release, drop drafts | Interpret what a change *means* for the audience |
| Compute compare range, collect PRs/commits/files | "new thing vs change" verb + category choice |
| Match ClickUp candidates | Pick the right task framing / merge related commits |
| Decide scope from DB | Write the Spanish value-first bullet |
| Render canvas + Slack notice | — |
| App Store / Pendiente gating | — |

## 10. Phased build plan (when we resume)

1. **Schema + collector-as-library.** Freeze the `ReleaseFacts` JSON schema; wrap `collect_app_changes.py`.
2. **State store.** DynamoDB tables for apps / entries / releases; migrate current canvas contents in as seed.
3. **Interpret Lambda.** Schema-locked, temp 0, memoized; golden-file tests over past releases (the
   canvases are the expected output).
4. **Renderers.** Canvas + Slack notice as pure functions of DB state; verify byte-parity against
   current canvases.
5. **Webhook ingress + queue + worker** wiring; idempotency + dedupe.
6. **App JA path**: deploy `workflow_run` + App Store poller + Pendiente state machine.
7. **HITL approval gate** (optional) before flipping to `published`.

Until this is built, the `ja-changelog` skill remains the source of truth for conventions — keep the
two in sync (this doc references SKILL.md's voice/emoji/format rules rather than duplicating them).
