---
name: ja-changelog
description: >-
  Generate client-facing release changelogs (in Spanish) for the Jalisco Alerta
  applications — the admin platforms EDL (earth-data-lab) and SIGEM (erlia-sigem), the executive
  dashboard Gabinete (ja-gabinete), and the consumer mobile app App JA (whose release notes come
  from the developer's Slack posts, not GitHub). Reads each repo's published GitHub releases (or,
  for App JA, the developer's Slack release messages), interprets what shipped, cross-checks the
  GitHub apps against their ClickUp tasks, and writes a value-oriented changelog grouped by app and
  by version, publishing it to the `ja-changelog` DB that powers the public changelog site. Use this
  whenever the user asks to "generate a changelog", "update the changelog", "write release notes",
  "what shipped" / "qué se liberó", or to summarize recent releases for the client/customer for any
  of these apps — including the mobile App JA — even if they don't name the skill explicitly. Use it
  for one app or all. Invoked with no mode word it does a combined run — publishes any released work
  not yet in the DB, then shows a preview of the work queued after the latest release. `released`
  publishes only the released work; `preview` (a.k.a. "simulado", e.g. "/ja-changelog preview") gives
  only the merged-but-unreleased look-ahead and halts if the DB is missing a published release.
---

# Jalisco Alerta — Changelog Generator

Produce a **changelog in Spanish** that communicates what shipped, not a raw git log.

**Audience — internal stakeholders who know the project deeply.** These are *not* the general public.
They are internal users of the Jalisco Alerta project (one of them is the **Product Owner**) who
understand the system, its modules, and its features well. So: they're non-developers, but you can be
**precise and specific** — name the modules/features/screens, don't over-simplify, and don't hide
technical work. Each bullet should answer "what changed, concretely?" — a new capability, an
improvement, a fix, or a noteworthy technical change. Write for someone who follows the project, not
someone hearing about it for the first time.

In `released` mode the changelog is **published to the `ja-changelog` DB** (write the release JSON,
commit, push — the public site deploys automatically); see "Publishing target" below. In `preview`
mode it's an **internal look-ahead draft presented in-conversation**, never written anywhere.

## The apps

| App | Role | Source of changes | Local folder | GitHub repo | ClickUp list id | Version |
|-----|------|-------------------|--------------|-------------|-----------------|---------|
| **EDL** | Admin platform — sends alerts to the JA mobile app; risk monitor | GitHub releases | `earth-data-lab` | `erliamx/erlia-earth-data-lab` | `901316895002` | `v2.x` |
| **SIGEM** | Admin platform — resource/vehicle/incident tracking during emergencies | GitHub releases | `erlia-sigem` | `erliamx/erlia-sigem` | `901322617067` | `v1.x` |
| **Gabinete** | High-level executive dashboard | GitHub releases | `gabinete` | `erliamx/ja-gabinete` | `901326844993` | `v0.x` |
| **App JA** | Consumer mobile app — receives EDL's alerts | **Slack** text + prod-deploy workflow | — | `erliamx/erlia-app` (no releases) | `901316895020` | `v2.x` |

Repos live under the working directory (default `/Users/marioferreira/Documents/repos/erlia`).
Process whichever apps the user asked for; default to all (admin apps + App JA).

The three GitHub apps use the workflow below. **App JA is different** — its release notes come from
Slack, not GitHub — see "App JA (mobile app)" near the end.

## Modes: default combined, `released`, `preview`

This skill has two underlying modes — **`released`** (publishes shipped releases to the DB → site)
and **`preview`** (the merged-but-unreleased backlog at the tip of `main`) — selected by a word in
the invocation. Everything about *interpreting* changes, the ClickUp cross-check, the Spanish
voice/style, and the "one bullet per change / nested sub-bullets" formatting is **identical**
everywhere — only **scope, collection, the App JA source, and the presentation** differ.

- **No mode word → default combined run.** Start with the **step-0 quick check** (always), then do
  **`released`**, then **`preview`** — in that order. **If the quick check shows every app is already
  documented, skip the released part entirely** (no collection, no DB write) and go straight to the
  preview. The released part publishes any released version not yet in the DB; the preview part then
  shows the work done **after the latest published release** (baseline = latest published tag → tip
  of `main`). In this combined run the preview part **does NOT run the preflight gate** — it shows
  the post-release backlog **even if released entries were just published this run** (the two are
  disjoint: documented→latest published, then latest published→`main`). This is the everyday "where
  do things stand" view: what shipped, and what's queued behind it. Present the two parts clearly
  separated — the released summary first (what you published, per step 6), then a divider, then the
  preview section with its banner.
- **`released`** (e.g. `/ja-changelog released` / `release`) → released only: the step-0 quick check,
  then the full workflow below. If the quick check shows everything is already documented, **that's
  the end of the run** (nothing to publish). No preview section.
- **`preview`** (e.g. `/ja-changelog preview` / `simulado` / `simulación`, optionally per-app) →
  preview only, and it **runs the preflight gate**: it HALTS if any published release is still
  missing from the DB (see preview mode below). Use this when you specifically want only the
  look-ahead and want to be stopped if the DB is behind.

**`preview` mode** answers *"what would the changelog say if we cut a release from the tip of each
system right now?"* — i.e. the **merged-but-unreleased** backlog. It is an **internal planning view,
NOT for the public changelog site.**

**Core invariant — a preview ALWAYS covers only `latest published tag → tip of main`, never released
work.** Released work is already in prod, so it is never part of a preview; whether or not it's
documented in the DB yet is **irrelevant to what the preview contains**. The preview section is
therefore the same in the default combined run and in standalone `preview`. The DB affects **only**
the standalone gate below — a *reminder to publish pending release notes first*, not a change to the
preview's scope. (This is why the default run can show the preview right after the just-published
release notes: the two are disjoint — `documented → latest published`, then `latest published → main`.)

Differences from the released workflow:

- **Preflight gate — for an explicit `preview` invocation, run this first and STOP if the DB isn't
  current.** (In the **default combined run** this gate is **skipped** — the released part runs right
  alongside, so just proceed.) Before computing a standalone preview, verify that every app you're
  about to preview has its **released** changelog fully in the DB. Do the released-mode scope check
  (step 1: last documented version per app from the DB, vs each app's **latest published release** —
  and for App JA, the **App Store live version** vs the documented version). If **any** in-scope app
  has a published release (or, for App JA, a store-live version) **newer than what the DB
  documents**, **HALT — do not produce the preview at all.** List the apps that are behind and their
  pending version(s), and tell the user to run `/ja-changelog` (released mode) first, publish those
  entries to the DB, then re-run `preview`. **Rationale:** a standalone preview of *unreleased* work
  is misleading and error-prone while already-*released* work is still missing from the DB — the DB
  must be an accurate "released" baseline before you look ahead. Only when the gate is clean for
  every in-scope app do you continue with the steps below.
- **Scope — always `latest published tag → tip of main`** (per the invariant above; never depends on
  the DB). Use commits, not release tags: the baseline per app is the **latest published release
  tag** (the collector reports it as `latestPublished`), and the target is the **tip of the default
  branch**.
- **Collect with `--preview`** instead of `--since`. Pull/fetch first, then:
  ```bash
  git -C <repo_path> fetch --all --tags --quiet
  python3 scripts/collect_app_changes.py <repo_path> --preview
  ```
  It emits **one** pseudo-release with `compareRange` = `<latestPublishedTag>..<defaultBranchHEAD>`,
  plus `unreleasedCommitCount`, `head`, and `headSha`. Pass `--since vX.Y.Z` to override the baseline
  or `--head <ref>` to override the tip. gh-API fallback if local git can't reach the tip:
  `gh api repos/<repo>/compare/<latestPublishedTag>...<defaultBranch>`.
- **Include everything — flagged-off and still-pending work too — but label it inline.** The whole
  point of a preview is to reveal what's cooking, so do **not** apply the released-mode exclusions.
  Tag any bullet that isn't client-live yet, e.g. append `— (pendiente: tras bandera de
  funcionalidad)` or `— (pendiente: tarea en revisión)`. Still fold pure internal/CI work into the
  one internal line.
- **App JA in preview** has no Slack store-text or App Store release for unreleased work, so derive
  its bullets **from commits** (the "no store text" path): baseline = the current **App Store** live
  version, target = tip of `main`; diff via
  `gh api repos/erliamx/erlia-app/compare/<liveVersionRef>...<defaultBranch>`. Mark them provisional.
  The App-Store gating rule does **not** apply in preview (nothing is being published).
- **Presentation — chat only, never written to the DB, and do NOT imply it's publishable.** Lead with
  a loud banner — **`🔮 SIMULACIÓN / PREVIEW — cambios aún NO publicados. No publicar en el sitio.`** —
  then present each app's changes as a normal readable draft (headings + bullets) under a placeholder
  heading like `Próxima versión (preview) — desde vX.Y.Z` (no real tag or date exists yet; show the
  baseline). Report `unreleasedCommitCount` per app so the user sees how much is queued.

The rest of this document describes **`released` mode**. In `preview` mode, reuse steps 3–5
(interpret / ClickUp / write bullets) verbatim and swap in the differences above.

## Publishing target: the `ja-changelog` repo → public site

The client changelog lives in **DynamoDB**, behind a CRUD API. The tooling lives in the
**`ja-changelog` repo** (a separate product repo, cloned locally at
**`~/Documents/repos/erlia/ja-changelog`** — call it `$JC`). In `released` mode you **POST the
release to the API** — that is the entire publish step. There is **no commit and no deploy**: the
site reads the API at runtime, so a published release is live immediately.

**Site:** `https://changelog.edl.jaliscoalerta.com` — **private**, behind a single shared user/pass
(HTTP Basic Auth). A release page is `/<slug>/<version>/` (the version keeps its `v` prefix and any
`-range`, e.g. `/edl/v2.301.4/`, `/edl/v2.294.8-v2.295.1/`); an app index is `/<slug>/`; the
cross-app period report is `/reporte/`.

| App | slug |
|-----|------|
| EDL | `edl` |
| SIGEM | `sigem` |
| Gabinete | `gabinete` |
| App JA | `app-ja` |

**Data model** (see `$JC/schema/release.schema.json`): a release =
`{version, date (ISO), status, note?, entries[]}`; each entry =
`{category, text, children?, pending?}` where `category` ∈ `nuevo` ✨ / `mejora` 🔧 /
`correccion` 🐛 / `tecnico` ⚙️. Everything about *writing bullets* — the Spanish voice, one-bullet-
per-change, nested sub-bullets, category choice — is in step 5 and `references/changelog-style.md`.

**Scope comes from the DB.** For each app, the "last documented version" is the newest release —
one command prints them all:

```bash
JC=~/Documents/repos/erlia/ja-changelog
python3 "$JC/scripts/latest_version.py" --profile erlia-prod-edl
# edl        v2.301.4                 2026-07-21  released
# sigem      v1.131.6                 2026-07-20  released
```

It reads DynamoDB directly with your AWS credentials (the API's GET routes are gated by the
CloudFront origin secret, so a direct read is simpler for tooling). Use each app's printed version
as the collector's `--since`. Add `--app <slug>` to limit it, `--json` for machine-readable output.

### Recipe: publish a release

`write_release.py` signs the request with **IAM (SigV4)** using whatever AWS credentials are
available — no API key. The API validates against the schema and rejects duplicates.

1. **Write the bullets to a flat file** `flat.md` — the same flat markdown this skill produces:
   top-level `- ✨ …` / `- 🔧 …` / `- 🐛 …` / `- ⚙️ …` bullets with 4-space-indented nested
   sub-bullets. (Alternatively build a JSON array of entry objects and pass `--entries`.)
2. **Publish:**
   ```bash
   JC=~/Documents/repos/erlia/ja-changelog
   python3 "$JC/scripts/write_release.py" --app <slug> --version <vX.Y.Z> --date <YYYY-MM-DD> \
     --status released --flat flat.md --profile erlia-prod-edl
   #   add --note "Sólo Android"  for a platform qualifier
   #   add --replace               only to overwrite an existing version on purpose
   #   add --dry-run               to print the body without sending
   ```
   **Never publish a version that isn't live for the client yet** — see the App JA store rule below.
   `--status pending` exists in the schema but is **not** used: don't publish unreleased versions.
   It exits non-zero (writing nothing) on validation failure or a duplicate version. If it reports
   the version already exists, **STOP** — it's already published.
   If several apps shipped in one run, publish each one; each is an independent API call.
   (Direct-to-main is intended — the reviewed draft is the artifact; revert via git if ever needed.)
   The repo uses an SSH remote via the 1Password agent; a lapsed grant can make `push`/`fetch` hang —
   if so, ask the user to authorize the on-screen 1Password prompt and retry.

#### After the push — post the notice (one per app, each with its site link)

**Always post a top-level notice** in `#ja-changelog` (`slack_send_message`, channel `C0BGNRZ3480`)
after pushing — the site deploy is **silent**, so this is how the team learns a release shipped.
**Standing, durable authorization from the user: send it automatically as part of publishing — do
NOT ask for confirmation, do not treat it as optional, never skip it, and never thread it (always
top-level).**

Post **one message per app that shipped** (not a combined message). Each message = a heading line, a
blank line, the version's bullets **verbatim** (including the category emoji ✨/🔧/🐛/⚙️, nested
sub-bullets indented), a blank line, then a final link line to the release's site page — Slack does
not embed the page, so the link must be explicit:

```
🚀 **EDL** — nueva versión **v2.287.1** publicada

• ✨ Se agrega el historial de las últimas 24 horas en la vista de detalle de un riesgo…
• 🔧 Se cambia la fuente de datos del monitor de riesgos para mostrar los riesgos registrados…
• ⚙️ Se agrega el endpoint de vista web para compartir notificaciones en WhatsApp/Telegram.

🔗 Ver más: https://changelog.edl.jaliscoalerta.com/edl/v2.287.1/
```

- Use **"Ver más:"**, NOT "Detalle:" — the message already carries the full changelog, so "Detalle"
  wrongly implies there's more detail on the page.
- The link is `https://changelog.edl.jaliscoalerta.com/<slug>/<version>/`. Verify the page returns
  **200** before relying on the link (the deploy can lag the push by a bit); `curl` may be
  unavailable in some shells — use `python3` + `urllib` to check.
- This `slack_send_message` integration renders standard `**bold**`; use it for the app name and
  version, as the working notices do.

`preview` mode never writes the DB or pushes (chat only).

**Hard rule — nothing reaches the changelog before the client can use it.** For **App JA** that means
a version is written to the DB **only once it is live in the Apple App Store** (see the App JA
section). Announced or deployed-but-not-yet-live versions are **not** published in any form — no
entry, no `pending` badge, no Slack notice. Report them to the user in-conversation instead (they
also show up in the preview section), and publish them on a later run once the store lists them.

## Workflow

Run these steps **per app**. Work app-by-app so a failure in one doesn't lose the others.

### 0. Quick check — ALWAYS run this first

**Every invocation starts here.** It answers "did anything actually ship?" cheaply, *before* any
collection work, and short-circuits the run when nothing did. (Distinct from the `preview` mode's
**preflight gate** below — that one halts when the DB is *behind*; this one skips work when
everything is *equal*.)

Build one table with, per app, the **latest production release** vs the **last documented version**:

| Value | How to get it (cheap) |
|-------|-----------------------|
| Publicada — EDL / SIGEM / Gabinete | `gh release list --repo <repo> --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName'` — no git fetch needed, and drafts/prereleases are excluded for you (see "Why drafts matter") |
| Publicada — App JA | the **App Store** live version (`itunes.apple.com/lookup`, see the App JA section) — the store is the only source of truth |
| Documentada — all apps | `python3 "$JC/scripts/latest_version.py"` — the newest release per app (see "Publishing target" above) |

**One command covers all four apps** — `latest_version.py` reads DynamoDB directly with your AWS
credentials and prints `slug · version · date · status` per app.

Present the table, then branch:

- **All apps equal → nothing shipped.** Say so plainly and **SKIP the released path entirely**: no
  collector run, no ClickUp cross-check, no DB write, no notice.
  - In **`released`** mode that's the end of the run.
  - In the **default combined run**, continue to the **preview** section — it's independent of the
    released path and may still have queued work.
  - In **`preview`** mode the existing preflight gate applies instead (it halts when the DB is
    *behind*, which this check just proved it isn't).
- **Any app differs → only that app has work.** Run steps 1–6 **only for the apps whose versions
  differ**; don't collect the up-to-date ones at all.

**App JA caveat:** the App Store version is what decides. If **store == documented**, App JA has
**nothing to publish** — even if a newer version was announced in Slack or deployed by the workflow.
Still check the newest successful deploy run (`gh run list … --workflow 178346105`): if it's newer
than the store, **report that version to the user as awaiting the store** (and it shows up in the
preview), but do **not** write it to the DB and do **not** post a notice.

### 1. Determine scope (what's new since the last changelog)

The default scope is **only releases newer than what's already documented in the DB** (the newest
release per app, from `latest_version.py` — see "Publishing target"). If the user instead asks for a
specific range or a full backfill, honor that: use the collector's `--since <tag>` (or omit `--since`
for a full backfill) and skip the DB lookup. Never guess a `--since` — a wrong one silently drops or
duplicates releases; if unsure, ask the user for the last documented version or an explicit range.

### 2. Pull and collect the raw changes

Pull the repo, then run the bundled collector. It filters out draft/prerelease tags and computes the
correct compare range for each published release (see "Why drafts matter" below):

```bash
git -C <repo_path> pull --ff-only
python3 scripts/collect_app_changes.py <repo_path> --since <last_documented_tag>
```

Omit `--since` for a full backfill. The script prints JSON: each in-scope release with its
`compareRange`, merged `prs` (number, branch, title), `commits`, and `changedFiles` (each an
`{status, path}` where status is `A`dded / `M`odified / `D`eleted / `R`enamed — see step 3 for why
added-vs-modified matters). (If a local `git pull`/`fetch` hangs, it's usually the 1Password SSH
grant — ask the user to authorize the prompt, or fall back to `gh api repos/<repo>/compare/<a>...<b>`,
which needs no SSH.)

### 3. Interpret what each release actually does

For each release, read the PR titles, commit subjects, and changed-file paths to understand
the substance. The PR title is usually the best signal. When a change is ambiguous or
high-impact and the title is terse (e.g. `fix: default fields`), inspect the actual diff:

```bash
git -C <repo_path> log <compareRange> --oneline
git -C <repo_path> show <commit_hash>        # or: git diff <compareRange> -- <path>
```

**New thing, or a change to an existing thing? Pick the verb accordingly — don't default to "Se
agrega."** A frequent error is writing "Se agrega una vista/función…" for what is actually a *change*
to something that already exists (e.g. swapping the data source behind an existing screen). Two
signals disambiguate: (1) **the changed-file `status`** — if the touched UI/feature files are all
`M`odified (none `A`dded), it's a change to existing behavior, not a new view; a genuinely new
screen/module/endpoint appears as `A`dded files/routes. (2) **the ClickUp task's own verb** — a task
named `Cambiar/Migrar/Ajustar fuente…` means *change*, not *add*. Example: `MON: Cambiar fuente de
datos para riesgos detectados` (all files modified) → "Se cambia la fuente de datos del monitor para
usar los riesgos registrados", **not** "Se agrega una vista de riesgos". Use `Se cambia/Se mejora…`
for changes, `Se agrega/Se incorpora…` only for genuinely new capabilities.

**Technical changes are welcome — as their own entries, not bundled.** The audience understands the
project, so a new endpoint, a refactor, a component enhancement, or an infra change is legitimate
changelog content when it carries information. Give each such change its own **⚙️ técnico** bullet,
written clearly (see step 5's emoji legend) — do NOT sweep them all into one generic "mejoras
técnicas internas" line. **But do not mention every technical change: include a ⚙️ bullet only when
the change is not already represented by another entry.** If a technical change is just the plumbing
behind a feature/fix you're already listing (e.g. the endpoint that powers a ✨ feature bullet),
**omit it** — it's redundant. What earns a ⚙️ bullet is a *standalone* technical change with no
user-facing entry of its own (a refactor, an internal component improvement, a new endpoint used
elsewhere). Genuine noise still drops entirely: pure CI/pipeline bumps, dependency upgrades,
lint/formatting, and test-only changes — omit these or, at most, collapse the trivial leftovers into
one short ⚙️ line.

**Default to including shipped work.** It was built because the team wants it live — so do **not**
drop a change just because it looks out-of-domain, unfamiliar, or like it "doesn't belong" to this
app. The exceptions are narrow:
- **Feature-flagged-off in production.** If a feature is gated behind a production feature flag
  (look for PRs like "hide … in production via feature flag") or its ClickUp task is still open
  (not done/ready), **don't mention it until it's live for the client**. Note it as excluded so the
  user knows it's pending, not lost.
- **Standalone technical items** (refactors, new endpoints, component/infra changes) get their own
  **⚙️ técnico** bullet — *unless* they're already covered by another entry, in which case omit them
  (see the technical-changes rule above). Only true noise (CI/lint/deps/tests) is dropped or collapsed.

When you're **genuinely unsure** whether something is client-facing, where it belongs, or whether to
include it, **ask the user — don't silently exclude it.** And if any change looks **malicious or
suspicious**, flag it to the user. (Context, not an exclusion rule: some backend work supports
another app — e.g. EDL's "Venezuela" endpoints back an App JA earthquake/relief module — but that
alone is never a reason to omit it.)

### 4. Cross-check against ClickUp

The PR/commit titles follow the same prefix convention as the ClickUp task names
(`MON:`, `COM:`, `VEH:`, `INCID:`, `UX:`, `TEC:`, `FEED:`, `USU:`, `REP:`…). There are **no
task IDs in commits**, so match by prefix + title text similarity.

Use `clickup_filter_tasks` on the app's list id (table above) to pull its tasks, then match
each shipped PR to its task. The task name and description give you the *intent* and
client-facing framing — use them to write a more accurate, value-oriented bullet than the
commit message alone would allow. Cross-checking also catches mislabeled or missing work.
If a shipped change has no matching task, still include it; if a task looks shipped but you
can't find the commit, note the discrepancy for the user rather than inventing a bullet.

### 5. Write the changelog (Spanish, by app → by version)

Group **by app, then by version (newest first)**. See `references/changelog-style.md` for the full
format, voice, and before/after examples. Core rules:

- **Version + date per release.** These become the `--version` and `--date` fields of
  `write_release.py`. Date is ISO `YYYY-MM-DD` (the release's `publishedAt`); the site renders it in
  Spanish. Keep the real tag (e.g. `v2.268.0`).
- **Merge releases that share the same publish date into one release** with a version-range value
  (lowest–highest, e.g. `v0.38.2-v0.38.3`) and list all their bullets together. Different days =
  separate releases. See `references/changelog-style.md`.
- **Flat bullet list** per version — no themed subsections.
- Spanish, impersonal, specific: bullets start with **"Se agrega…/Se mejora…/Se cambia…/Se corrige el
  error que causaba que…"**. Lead with what changed; you may name the concrete module/screen/feature
  since the audience knows the project (see the audience note at the top).
- **Prefix every bullet with a category emoji** (one leading emoji + a space, before the "Se…") — the
  writer maps it to the entry's `category`:
  - **✨ Nueva funcionalidad** (`nuevo`) — a genuinely new capability (`Se agrega/Se incorpora/Se habilita…`).
  - **🔧 Mejora o cambio** (`mejora`) — a change/improvement to something that already exists (`Se
    mejora/Se cambia/Se ajusta/Se optimiza…`).
  - **🐛 Corrección** (`correccion`) — a bug fix (`Se corrige el error que causaba que…`).
  - **⚙️ Técnico** (`tecnico`) — a standalone technical change (endpoint, refactor, component/infra
    enhancement) that isn't already represented by another entry (see step 3's technical-changes rule).
  On a parent bullet with nested sub-bullets, put the emoji on the **parent only**; sub-bullets have
  none. Pick the emoji by what the change *is*, not by wording — a reworded existing screen is 🔧, not
  ✨. When unsure between ✨ and 🔧, use the step-3 "new thing vs change to existing" test (Added files
  / `Cambiar` task verb → 🔧).
- **One bullet per distinct change.** Never pack several distinct changes into a single bullet
  joined by commas. If a single feature has several sub-parts worth listing (e.g. a new module with
  multiple screens), use a parent bullet ending in `:` with **nested sub-bullets** (4-space indent in
  the flat file). Commas are fine only inside one coherent sentence, not as a way to enumerate
  separate items.
- Merge several commits into one bullet only when they're genuinely one change.
- No PR numbers, branch names, or English commit jargon in the body.
- **Technical work → individual ⚙️ bullets, not one generic line.** Surface each *noteworthy,
  standalone* technical change (endpoint, refactor, component/infra enhancement) as its own clear ⚙️
  bullet — but only when it isn't already conveyed by another entry (omit the plumbing behind a
  feature you already listed). Do NOT default to the old catch-all "Se realizan diversas mejoras
  técnicas e internas…" line for everything. Genuine trivia (CI/lint/deps/tests) is dropped, or at
  most collapsed into a single short ⚙️ line — never a comma-enumeration.

### 6. Publish (released) or present (preview)

**In `released` mode, write each new release into the `ja-changelog` DB and push** via the "add a
release to the DB" recipe in "Publishing target" above (`write_release.py` → validate → commit to
`main` → push; GitHub Actions deploys the site). Then post the Slack notice(s) (see "After the push
— post the notice"), and briefly report to the user what you published (version + the site page
`https://changelog.edl.jaliscoalerta.com/<slug>/<version>/`) and any step-4 discrepancies or
intentionally-skipped work.

**In `preview` mode, present the look-ahead draft in-conversation only** — the loud banner, then each
app under its `Próxima versión (preview) — desde vX.Y.Z` heading with readable bullets, and the
`unreleasedCommitCount` per app. Never write it to the DB or push.

## App JA — the mobile app (source: Slack, not GitHub)

App JA's repo (`erliamx/erlia-app`) has **no GitHub releases**, so the collector doesn't apply.
Instead: **which versions shipped** comes from a GitHub Actions workflow, and **the descriptive
text** comes from the developer's Slack posts. In the DB, App JA is just another app — slug
`app-ja`, same schema and same publish call as the rest.

### Scope — which versions actually shipped (authoritative)
A version is "released" only when it deployed to the production store. The source of truth is the
**"Deploy Android production App"** workflow (id `178346105`) in `erliamx/erlia-app`: a run that
**succeeded** on a branch named **`rc/X.Y.Z`** = version `X.Y.Z` shipped to production, and the run
date is the release date.

```bash
gh run list --repo erliamx/erlia-app --workflow 178346105 --status success \
  --limit 40 --json headBranch,createdAt \
  --jq '.[] | select(.headBranch|test("^rc/[0-9]")) | "\(.headBranch[3:])  \(.createdAt[:10])"'
```

The last documented version is App JA's newest release in the DB
(`latest_version.py --app app-ja`). Add every shipped version newer than that, using the **deploy
date** for the date. **Versions are commonly skipped** (e.g. v2.22/2.25 never deployed) — the
workflow tells you exactly what shipped, so don't assume contiguous numbering.

**The `rc/X.Y.Z` branch name is a convention, not a guarantee — don't trust the regex alone.**
Developers sometimes deploy a version from a differently-named branch (e.g. v2.27.0 shipped from
`rc/feature/venezuela`, PR #137), so the `test("^rc/[0-9]")` filter above **silently misses it** and
the version looks unshipped when it actually went live. So: if a Slack-announced version has **no**
matching `rc/X.Y.Z` deploy, do **not** conclude it's pending — list *all* recent successful runs of
this workflow regardless of branch name and match by date/PR/feature to the announcement before
deciding. Widen the query by dropping the `select(...)` filter:
```bash
gh run list --repo erliamx/erlia-app --workflow 178346105 --status success \
  --limit 40 --json number,headBranch,createdAt \
  --jq '.[] | "#\(.number)  \(.headBranch)  \(.createdAt[:10])"'
```

**The Apple App Store is the single source of truth for whether a version has shipped.** The GitHub
workflow and the Slack post only tell you what the *pipeline* did; the store tells you what the
*client can actually download*. A version is "released" **only** once it appears in the App Store —
so confirm there before you write any App JA version at all — the store is what gates publishing
(see the "do not publish before the store" rule below).
- **Apple App Store** (the authoritative check — clean JSON, gives the live version **and** its
  release date):
  ```bash
  curl -s "https://itunes.apple.com/lookup?bundleId=mx.erlia.jal.ios&country=mx" \
    | python3 -c "import sys,json; a=json.load(sys.stdin)['results'][0]; print(a['version'], a['currentVersionReleaseDate'][:10])"
  ```
  (App Store id `6748151640`.) When this returns the version you're documenting, it **is** live —
  use `currentVersionReleaseDate` as the `--date`.
- **Google Play** (Android pkg `mx.erlia.jal.android`) has **no public version API**; scrape the
  details page and read the current-version token (heuristic — Google can change the structure):
  ```bash
  curl -s -A "Mozilla/5.0" "https://play.google.com/store/apps/details?id=mx.erlia.jal.android&hl=es&gl=US" \
    | grep -oE '\[\[\["[0-9]+\.[0-9]+\.[0-9]+"\]\]' | head -1
  ```
  Google Play is **informational only** — it does **not** authorize publishing (Apple does).
- The store only reports the **currently-live** version (not historical per-version dates), so it's
  the source of truth for "is the newest announced version live yet?"; use the deploy workflow for
  dates of older versions. Single-store releases are rare, so assume iOS and Android ship together;
  in the uncommon case they diverge, **don't publish** until the App Store lists it, and flag it to
  the user rather than guessing a `--note "Sólo Android"` / `"Solo iOS"` qualifier.

### Find the descriptive text per version
The developer **Diego R Galindo** (`U099H6TPS04`) posts each release's store text ("texto para
tiendas") in Slack. As of **1 jul 2026** the dedicated channel is **#app-changelog** (id
`C0BEE1F2UR3`) — read it first; the older **#app-jalisco-alerta** (id `C099DKW3MV0`) holds prior
history. Use `slack_read_channel` on the channel (and `slack_read_thread` for replies).
- A **relevant message** = a version number (`Versión 2.27.0` / `version 2.26.0`) followed by a
  fenced ```code block``` of consumer-facing prose. **Skip** join/approval chatter, feedback-form
  entries, and screenshots.
- **Several RCs per version.** The same version may get multiple posts/RCs in #app-changelog as it
  is refined. **Read them all (including thread replies), accumulate their content into that one
  version's draft, mention every RC to the user, and keep refining that draft on each run until the
  version reaches the App Store and you finally publish it** — its content may still be changing.
- **A version is often announced here before it reaches the store.** #app-changelog gives the
  *notes*; the Slack post and the deploy workflow only mean the build was *cut/deployed*, **not** that
  the client can download it.
- **DO NOT publish a version that isn't live in the App Store yet — not in any form.** No DB entry,
  no `pending` badge, no Slack notice. The changelog must only ever describe what the client can
  actually use. Instead, **report the announced/deployed version to the user in-conversation** (and
  it will appear in the preview section), and publish it on a later run once the store lists it.
- **The Apple App Store is the single source of truth for publishing an App JA version.** On every
  run, look up the live App Store version (the `itunes.apple.com/lookup` command above):
  - If the store's live version is **older** than the announced one → **write nothing**, regardless
    of what Slack, the deploy workflow, or Google Play say. A cut build, a green pipeline, or an
    Android-only rollout is **not** enough. Just tell the user it's waiting on the store.
  - Once the App Store lists that version → write it with `--status released` and the store's
    `currentVersionReleaseDate` as `--date`, then commit + push and post the notice as usual.
    (Accumulate its Slack RC texts/commits across runs meanwhile, so the entry is ready when it ships.)
- **If a shipped version has no store text** (e.g. hotfix v2.26.1), derive one concise client-facing
  line from its commits (compare the rc run's `headSha` against the previous version's via
  `gh api repos/erliamx/erlia-app/compare/<prevSha>...<thisSha>`), or a generic stability line.

### Reformat — elevate the tone for product stakeholders
The Slack source is written for **end users** ("Ahora puedes…", "disfruta…", "para ti", "tu
experiencia"). But our changelog's audience is the **internal project stakeholders** described in the
audience note at the top (they know the project; one is the Product Owner), so use the **same formal,
impersonal register as the admin-app sections** — don't carry over the end-user marketing voice.
Convert the prose into changelog bullets:
- Use **impersonal, specific phrasing**: "Se agrega… / Se incorpora… / Se mejora… / Se corrige el
  error que causaba que…". **Drop** "Ahora puedes…", "disfruta…", "para ti", "tu experiencia".
- Keep it readable (not raw engineering jargon), just more formal than the Slack text. E.g. Slack
  "Ahora puedes calificar las alertas que recibes" → "Se agrega la posibilidad de calificar las
  alertas recibidas".
- **Prefix each bullet with the category emoji** (✨/🔧/🐛/⚙️), same legend as the admin apps (step 5).
  App JA's store text rarely surfaces standalone ⚙️ technical items, so it's usually ✨/🔧/🐛.
- One bullet per distinct change; nested sub-bullets for enumerations (e.g. a Mundial content list —
  parent bullet ending in `:` then indented sub-bullets, emoji on the parent only).
- `--date` = the App Store's `currentVersionReleaseDate` for the version you're publishing. Add
  `--note "Sólo Android"` / `"Solo iOS"` only if the version is genuinely platform-specific. If the
  version is announced but not yet live in the App Store, **don't write it at all** — keep the draft
  and publish on a later run (see the scope rules above).

Present App JA exactly like the other apps (step 6). See `references/changelog-style.md` for worked
App JA before/after examples.

## Why drafts matter (don't skip this)

These repos publish **many draft releases** (often one per PR) interleaved with the real
published releases. The client only ever receives the **published, non-draft, non-prerelease**
ones. A published release usually bundles several draft-tagged commits, so its own release body
is often empty or lists only one PR — never trust it alone. The collector script handles this:
it keeps only published releases and diffs *previous-published-tag → this-published-tag*, which
captures everything that shipped. If you ever collect changes by hand, replicate that logic.
