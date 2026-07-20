---
name: ja-changelog
description: >-
  Generate client-facing release changelogs (in Spanish) for the Jalisco Alerta
  applications — the admin platforms EDL (earth-data-lab) and SIGEM (erlia-sigem), the executive
  dashboard Gabinete (ja-gabinete), and the consumer mobile app App JA (whose release notes come
  from the developer's Slack posts, not GitHub). Reads each repo's published GitHub releases (or,
  for App JA, the developer's Slack release messages), interprets what shipped, cross-checks the
  GitHub apps against their ClickUp tasks, and writes a value-oriented changelog grouped by app and
  by version, matching the client's changelog Google Doc. Use this whenever the user asks to
  "generate a changelog", "update the changelog", "write release notes", "what shipped" / "qué se
  liberó", or to summarize recent releases for the client/customer for any of these apps — including
  the mobile App JA — even if they don't name the skill explicitly. Use it for one app or all.
  Invoked with no mode word it does a combined run — pending released updates (paste-ready) followed
  by a preview of the work queued after the latest release. `released` gives only the paste-ready
  release notes; `preview` (a.k.a. "simulado", e.g. "/ja-changelog preview") gives only the
  merged-but-unreleased look-ahead and halts if the Doc is missing a published release.
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

The output is a **draft for the user to review and paste** into the changelog Google Doc.
Do not write to the Doc directly — the Doc is read-only style/scope reference.

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

This skill has two underlying modes — **`released`** (documents published releases into the client
Doc) and **`preview`** (the merged-but-unreleased backlog at the tip of `main`) — selected by a word
in the invocation. Everything about *interpreting* changes, the ClickUp cross-check, the Spanish
voice/style, and the "one bullet per change / nested sub-bullets" formatting is **identical**
everywhere — only **scope, collection, the App JA source, and the presentation** differ.

- **No mode word → default combined run.** Start with the **step-0 quick check** (always), then do
  **`released`**, then **`preview`** — in that order. **If the quick check shows every app is already
  documented, skip the released part entirely** (no collection, no canvas write) and go straight to
  the preview. The released part produces the paste-ready copy-boxes for any published
  release not yet in the Doc; the preview part then shows the work done **after the latest published
  release** (baseline = latest published tag → tip of `main`). In this combined run the preview part
  **does NOT run the preflight gate** — it shows the post-release backlog **even if the released
  entries above it still need pasting** (the two are shown together, disjoint: documented→latest
  published, then latest published→`main`). This is the everyday "where do things stand" view: what
  to paste now, and what's queued behind it. Present the two parts clearly separated — released
  copy-boxes first (step 6), then a divider, then the preview section with its banner.
- **`released`** (e.g. `/ja-changelog released` / `release`) → released only: the step-0 quick check,
  then the full workflow below. If the quick check shows everything is already documented, **that's
  the end of the run** (nothing to publish). No preview section.
- **`preview`** (e.g. `/ja-changelog preview` / `simulado` / `simulación`, optionally per-app) →
  preview only, and it **runs the preflight gate**: it HALTS if any published release is still
  missing from the Doc (see preview mode below). Use this when you specifically want only the
  look-ahead and want to be stopped if the Doc is behind.

**`preview` mode** answers *"what would the changelog say if we cut a release from the tip of each
system right now?"* — i.e. the **merged-but-unreleased** backlog. It is an **internal planning view,
NOT for the client Doc.**

**Core invariant — a preview ALWAYS covers only `latest published tag → tip of main`, never released
work.** Released work is already in prod, so it is never part of a preview; whether or not it's
documented in the Doc yet is **irrelevant to what the preview contains**. The preview section is
therefore the same in the default combined run and in standalone `preview`. The Doc affects **only**
the standalone gate below — a *reminder to paste pending release notes first*, not a change to the
preview's scope. (This is why the default run can show the preview right below still-unpasted release
notes: the two are disjoint — `documented → latest published`, then `latest published → main`.)

Differences from the released workflow:

- **Preflight gate — for an explicit `preview` invocation, run this first and STOP if the Doc isn't
  current.** (In the **default combined run** this gate is **skipped** — the released part is shown
  right alongside, so just proceed.) Before computing a standalone preview, verify that every app you're
  about to preview has its **released** changelog fully in the Doc. Do the released-mode scope check
  (step 1: last documented version per app from the Doc, vs each app's **latest published release** —
  and for App JA, the **App Store live version** vs the documented version). If **any** in-scope app
  has a published release (or, for App JA, a store-live version) **newer than what the Doc
  documents**, **HALT — do not produce the preview at all.** List the apps that are behind and their
  pending version(s), and tell the user to run `/ja-changelog` (released mode) first, paste those
  entries into the Doc, then re-run `preview`. **Rationale:** a standalone preview of *unreleased*
  work is misleading and error-prone while already-*released* work is still missing from the Doc — the
  Doc must be an accurate "released" baseline before you look ahead. Only when the gate is clean for
  every in-scope app do you continue with the steps below.
- **Scope — always `latest published tag → tip of main`** (per the invariant above; never depends on
  the Doc). Use commits, not release tags: the baseline per app is the **latest published release
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
  The ` - Pendiente` / App-Store-gating rules do **not** apply in preview (nothing is released).
- **Presentation is different: do NOT use the Doc copy-boxes and do NOT imply it's paste-ready.**
  Lead with a loud banner — **`🔮 SIMULACIÓN / PREVIEW — cambios aún NO publicados. No pegar en el
  Doc del cliente.`** — then present each app's changes as a normal readable draft (headings +
  bullets) under a placeholder heading like `Próxima versión (preview) — desde vX.Y.Z` (no real tag
  or date exists yet; show the baseline). Report `unreleasedCommitCount` per app so the user sees how
  much is queued.

The rest of this document describes **`released` mode**. In `preview` mode, reuse steps 3–5
(interpret / ClickUp / write) verbatim and swap in the four differences above.

## Publishing target: Slack canvases (per app) — the new source of truth

The client changelog now lives in **four per-app Slack canvases** in `#ja-changelog` (channel
`C0BGNRZ3480`, team `T099H5TTQE8`), which **replace the Google Doc**. In `released` mode you now
**write the new entry into the right canvas** instead of emitting Doc copy-boxes.

| App | Canvas id | Product `#` header (exact) |
|-----|-----------|----------------------------|
| App JA | `F0BFDQSP23Z` | `# App Jalisco Alerta` |
| Gabinete | `F0BFDQTE607` | `# JA Gabinete` |
| EDL | `F0BGPFZ22EL` | `# Earth Data Lab` |
| SIGEM | `F0BFNUBFD6X` | `# Sistema de Gestión de Emergencias` |

Canvas base URL: `https://erlia.slack.com/docs/T099H5TTQE8/<CANVAS_ID>`.

**Canvas structure** (match exactly): `# Product` → `**Meses:** [Mes Año](…) · …` (clickable month
index) → `## Mes Año` → `[↑ Arriba](…)` (back-to-top) → `### vX.Y.Z (D mes AAAA)` → bullets. Newest
month first; newest release first within a month.

**Scope now comes from the canvas, not the Doc.** For each app, the "last documented version" =
the **newest `### vX.Y.Z`** in its canvas (`slack_read_canvas <id>`, take the first `### v…`). Use
that as the collector's `--since`. (The Google Doc is legacy — only fall back to it if asked.)

### ⚠️ Slack-canvas tool quirks — do not forget
- `slack_update_canvas` action=`replace` **with** a `section_id` **INSERTS A DUPLICATE** in this
  integration (it does NOT replace in place). **Never use it.**
- Safe primitives ONLY: `replace` **without** `section_id` (full-canvas overwrite) and `prepend`
  **with** `section_id` (insert right after an element — no duplicate).
- There is **no delete** (empty-content replace is blocked). Fix any mistake by **full-rebuilding**
  the canvas, not by trying to remove a line.
- The month-index and `↑ Arriba` links are clickable deep-links; Slack always shows a hover preview
  card (unavoidable). Native browsing = collapsible `##` headers.

### Recipe: add a release to a canvas

**Pick the path by whether the new release's month header already exists in the canvas:**

- **Same month (the common case)** — the newest month header (e.g. `## Julio 2026`) already exists →
  use the **targeted insert** (Path A). One safe `prepend`, no index/link rebuild. **Preferred:**
  ~4–5× cheaper, and it never touches the `**Meses:**` index or `↑ Arriba` links, so they can't break.
- **New month** — this release is the FIRST of a new month (its `## Mes Año` header doesn't exist yet,
  so the `**Meses:**` index must gain that month) → use the **full rebuild** (Path B). The index is a
  single line that can't be edited surgically, so the whole canvas is rebuilt.

#### Path A — targeted insert (same month; preferred)

1. `slack_read_canvas <id>`. **If the new `vX.Y.Z` is already present, STOP** — it's already published
   (don't duplicate); just sanity-check the index and report. Otherwise, from `section_id_mapping`
   find the id of the **current top version entry** (the newest `### vX.Y.Z` under the newest month).
2. `slack_update_canvas` edit_type=`prepend`, `section_id` = that top-entry id, content = the new
   `### vX.Y.Z (D mes AAAA)` heading + its bullets (use `###`, the canvas's version level; keep the
   category emojis; nested sub-bullets indented). `prepend` WITH a section_id inserts *before* that
   entry — safe, no duplicate. This is the **one allowed use of a section_id** (never with `replace`).
3. Do **not** touch the `**Meses:**` index or the `↑ Arriba` links — the month already exists, so they
   stay correct. `slack_read_canvas <id>` once to verify the new entry is first under its month,
   appears exactly once, and the index is intact.

Then post the notice (shared step below).

#### Path B — full rebuild (new month, or to normalize a drifted canvas)

The `**Meses:**` index must gain the new month and the `↑ Arriba` links must stay consistent, and
neither can be edited surgically — so rebuild the whole canvas:

1. `slack_read_canvas <id>` → save its markdown to `dump.md`.
2. `python3 scripts/render_canvas.py --extract < dump.md > flat.md` — strips the index / `↑ Arriba` /
   `## Mes` headers back to a flat `## vX.Y.Z (fecha)` entry list.
3. Put the **new** `## vX.Y.Z (D mes AAAA)` + bullets at the **TOP** of `flat.md`.
4. `python3 scripts/render_canvas.py --product "<product name>" < flat.md > body.md` — regroups by month.
   **Pass the product name WITHOUT the leading `# `** (e.g. `--product "App Jalisco Alerta"`, not
   `"# App Jalisco Alerta"`): the script prepends `# ` itself, so passing the `#` yields a broken
   double-hash header `# # …` that then breaks the step-6 product-header id match.
5. `slack_update_canvas` action=`replace`, **no** `section_id`, content = `body.md` (full overwrite;
   clears the old index/links too).
6. `slack_read_canvas <id>` → from `section_id_mapping` take the product-header id and every
   `## Mes Año` id (document order), then:
   - `prepend` under the **product-header** id →
     `**Meses:** ` + each month as `[Mes Año](https://erlia.slack.com/docs/T099H5TTQE8/<id>?focus_section_id=<monthId>)` joined by ` · `.
   - `prepend` under **each month-header** id → `[↑ Arriba](https://erlia.slack.com/docs/T099H5TTQE8/<id>?focus_section_id=<productHeaderId>)`.
#### After the write (BOTH paths) — post the notice

**Always post a top-level notice** in `#ja-changelog` (`slack_send_message`, channel
   `C0BGNRZ3480`) after writing the canvas(es) — canvas edits are **silent**, so this is how the team
   learns a release shipped. **This is standing, durable authorization from the user: send it
   automatically as part of publishing a release — do NOT ask for confirmation first, do not treat it
   as optional.** Never skip it, and never thread it (always top-level).
   **Message content — paste a COPY of the release's changelog bullets, and do NOT link the canvas.**
   A bare canvas URL makes Slack render a big preview card that wastes space and is awkward to use, so
   **omit the link entirely** — paste the just-published version's bullets inline so the team reads
   what shipped without leaving the channel. The canvas holds the full history for anyone who wants
   the older entries. Format per app (heading line, blank line, then the bullets exactly as written to
   the canvas for that version, keeping any nested sub-bullets indented):
   ```
   🚀 **EDL** — nueva versión **v2.287.1** publicada

   • ✨ Se agrega el historial de las últimas 24 horas en la vista de detalle de un riesgo…
   • 🔧 Se cambia la fuente de datos del monitor de riesgos para mostrar los riesgos registrados…
   • ⚙️ Se agrega el endpoint de vista web para compartir notificaciones en WhatsApp/Telegram.
   ```
   The bullets are a verbatim copy of what you wrote to the canvas for that version, **including the
   category emoji** (✨/🔧/🐛/⚙️). (This `slack_send_message` integration renders standard `**bold**`;
   use it for the app name and version, as the working notices do.)
   If **several apps** shipped in the same run, **combine them into ONE message**, one such per-app
   block separated by a blank line (don't send several separate messages).

**Run either path in a subagent** — `slack_read_canvas` returns 60–80k chars, so even Path A's single
read should stay out of your main context; Path B is heavier still (full body + a second read).
Always restate the "never `replace` with a `section_id`" rule to the subagent. `preview` mode never
writes to a canvas (chat only). The App JA `Pendiente` / App-Store-gating rules are unchanged.

**Note on the flaky full-overwrite:** in this integration `replace` *without* `section_id` (Path B
step 5) has intermittently been rejected (`missing_required_field:section_id`). If it fails, do NOT
switch to `replace` *with* a section_id (that duplicates) — fall back to inserting each new/changed
section via `prepend`+section_id, which is what Path A does and has been reliable.

## Workflow

Run these steps **per app**. Work app-by-app so a failure in one doesn't lose the others.

### 0. Quick check — ALWAYS run this first

**Every invocation starts here.** It answers "did anything actually ship?" cheaply, *before* any
collection work, and short-circuits the run when nothing did. (Distinct from the `preview` mode's
**preflight gate** below — that one halts when the canvas is *behind*; this one skips work when
everything is *equal*.)

Build one table with, per app, the **latest production release** vs the **last documented version**:

| Value | How to get it (cheap) |
|-------|-----------------------|
| Publicada — EDL / SIGEM / Gabinete | `gh release list --repo <repo> --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName'` — no git fetch needed, and drafts/prereleases are excluded for you (see "Why drafts matter") |
| Publicada — App JA | the **App Store** live version (`itunes.apple.com/lookup`, see the App JA section) — the store is the only source of truth |
| Documentada — all apps | the newest `### vX.Y.Z` in that app's canvas |

**Reading the four canvases is expensive** (each returns 60–80k chars). Do NOT read them into your
own context — delegate to a **subagent** that reads all four and returns **only** the newest
`### vX.Y.Z` per app (four short lines).

Present the table, then branch:

- **All apps equal → nothing shipped.** Say so plainly and **SKIP the released path entirely**: no
  collector run, no ClickUp cross-check, no canvas write, no notice.
  - In **`released`** mode that's the end of the run.
  - In the **default combined run**, continue to the **preview** section — it's independent of the
    released path and may still have queued work.
  - In **`preview`** mode the existing preflight gate applies instead (it halts when the canvas is
    *behind*, which this check just proved it isn't).
- **Any app differs → only that app has work.** Run steps 1–6 **only for the apps whose versions
  differ**; don't collect the up-to-date ones at all.

**App JA caveat:** "store == documented" only means no *released* work. A newer version may still be
announced/deployed but not yet live (the ` - Pendiente` case). So for App JA also check the newest
successful deploy run (`gh run list … --workflow 178346105`); if it's newer than both the store and
the documented version, App JA **does** have work (a `Pendiente` entry) — don't skip it.

### 1. Determine scope (what's new since the last changelog)

The default scope is **only releases newer than what's already documented**. **The changelog now
lives in the per-app Slack canvases (see "Publishing target: Slack canvases" above) — read the last
documented version from the app's canvas (its newest `### vX.Y.Z`), not the Google Doc.** The Doc
steps below are legacy; use them only if explicitly asked to work against the Doc.

Legacy (Google Doc) scope lookup:

- **Doc id**: `1LYZFTd64Q_7hvT5k5-heTKeQZqR_mKRIqIbzaYdwQ-U` (the client's master changelog). Read
  it with the available Google Docs/Drive tool. It's large (~70k chars) — if the read result is
  too big for context, delegate the extraction to a subagent and ask it to return only the
  format conventions and the last documented version per app.
- The Doc is organized **by app** (`# EDL`/`# Earth Data Lab`, `# SIGEM`/`# Sistema de Gestión
  de Emergencias`, `# Gabinete`/`# JA Gabinete`), versions newest-first. Find the **highest real
  version under that app's section** — that tag is your `--since`.
- **Skip placeholder stubs** when finding the last version: headings like `## v2.. ( junio
  2026)` or a version whose only bullet is `- Feature` are reserved templates, not real
  releases. Use the most recent entry that has genuine changelog content.
- If the Doc is unavailable, ask the user for the last documented version per app, or an explicit
  range. Never guess — a wrong `--since` silently drops or duplicates releases.

If the user instead asks for a specific range or a full backfill, honor that and skip the Doc lookup.

### 2. Pull and collect the raw changes

Pull the repo, then run the bundled collector. It filters out draft/prerelease tags and
computes the correct compare range for each published release (see "Why drafts matter" below):

```bash
git -C <repo_path> pull --ff-only
python3 scripts/collect_app_changes.py <repo_path> --since <last_documented_tag>
```

Omit `--since` for a full backfill. The script prints JSON: each in-scope release with its
`compareRange`, merged `prs` (number, branch, title), `commits`, and `changedFiles` (each an
`{status, path}` where status is `A`dded / `M`odified / `D`eleted / `R`enamed — see step 3 for why
added-vs-modified matters).

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

Group **by app, then by version (newest first)**. Match the existing Google Doc exactly. See
`references/changelog-style.md` for the full format, voice, and before/after examples. Core rules:

- Heading per version: `## vX.Y.Z (D mmmm aaaa)` with the date as `18 junio 2026` (lowercase
  Spanish month, no "de"). Place each app's versions under its `# Codename` / `# Full Name` H1s.
- **Merge releases that share the same publish date into one entry** with a version-range heading
  (lowest–highest, e.g. `v0.38.2-v0.38.3 (25 junio 2026)`) and list all their bullets together.
  Different days = separate entries. See `references/changelog-style.md`.
- **Flat bullet list** per version — no themed subsections.
- Spanish, impersonal, specific: bullets start with **"Se agrega…/Se mejora…/Se cambia…/Se corrige el
  error que causaba que…"**. Lead with what changed; you may name the concrete module/screen/feature
  since the audience knows the project (see the audience note at the top).
- **Prefix every bullet with a category emoji** (one leading emoji + a space, before the "Se…"):
  - **✨ Nueva funcionalidad** — a genuinely new capability (`Se agrega/Se incorpora/Se habilita…`).
  - **🔧 Mejora o cambio** — a change/improvement to something that already exists (`Se mejora/Se
    cambia/Se ajusta/Se optimiza…`).
  - **🐛 Corrección** — a bug fix (`Se corrige el error que causaba que…`).
  - **⚙️ Técnico** — a standalone technical change (endpoint, refactor, component/infra enhancement)
    that isn't already represented by another entry (see step 3's technical-changes rule).
  On a parent bullet with nested sub-bullets, put the emoji on the **parent only**; sub-bullets have
  none. Pick the emoji by what the change *is*, not by wording — a reworded existing screen is 🔧, not
  ✨. When unsure between ✨ and 🔧, use the step-3 "new thing vs change to existing" test (Added files
  / `Cambiar` task verb → 🔧).
- **One bullet per distinct change.** Never pack several distinct changes into a single bullet
  joined by commas — that breaks the Doc's convention. If a single feature has several sub-parts
  worth listing (e.g. a new module with multiple screens), use a parent bullet ending in `:` with
  **nested sub-bullets**, the way the Doc does. Commas are fine only inside one coherent sentence,
  not as a way to enumerate separate items.
- Merge several commits into one bullet only when they're genuinely one change.
- No PR numbers, branch names, or English commit jargon in the body.
- **Technical work → individual ⚙️ bullets, not one generic line.** Surface each *noteworthy,
  standalone* technical change (endpoint, refactor, component/infra enhancement) as its own clear ⚙️
  bullet — but only when it isn't already conveyed by another entry (omit the plumbing behind a
  feature you already listed). Do NOT default to the old catch-all "Se realizan diversas mejoras
  técnicas e internas…" line for everything. Genuine trivia (CI/lint/deps/tests) is dropped, or at
  most collapsed into a single short ⚙️ line — never a comma-enumeration.

### 6. Publish (canvas) or present (legacy/preview)

**In `released` mode, write each new entry into the app's Slack canvas** via the "add a release to a
canvas" recipe in "Publishing target: Slack canvases" above (Path A targeted insert for a same-month
release — the common case; Path B full rebuild only when the release opens a new month), then briefly
report to the user what you wrote (version + canvas link) and any step-4 discrepancies. Fall back to the Doc copy-boxes below **only** if the
user explicitly asks for Doc output. The copy-box format below is still used for **`preview`** output
and for the legacy Doc path.

**Never save a draft file.** Output the changelog directly in the conversation, formatted so the
user can copy each piece straight into Google Docs (where headings and bullets are applied by the
Doc, not by Markdown). The user pastes manually, so:

- For **each version**, emit **two separate fenced code blocks** (each gets its own copy button):
  1. The **heading line only**: `vX.Y.Z (D mmmm aaaa)` — no `##`, no leading dash.
  2. The **bullets** for that version, **with NO leading `- ` markers** (one change per line), so
     they don't collide with the Doc's automatic bullets. Indent nested sub-items with a **real Tab
     character** (U+0009), **not spaces**. Google Docs does **not** auto-nest from the pasted tab,
     but this lets the user paste the whole block in one shot and then quickly demote the tabbed
     lines / delete the tabs — which the user prefers over multiple copy-paste cycles per level.
     (Emit an actual tab byte in the code block, not the literal characters "\t" and not spaces.)
- Group these under a plain-text label per app (`# Codename` / `# Full Name`), versions newest-first.
  **Prefix the app label with 🚀 when that app has pending changes to add to the Doc** — i.e. it has
  a published release newer than what the Doc documents (the entries you're presenting for pasting).
  Apps with nothing pending get **no** emoji. (So a heading reads `🚀 SIGEM / Sistema de Gestión de
  Emergencias` only when SIGEM has release notes waiting to be pasted; `EDL / Earth Data Lab` with no
  emoji means EDL is already up to date.) This 🚀 marks the **released** (to-paste) sections only — in
  a default combined run it does not go on the preview section's labels, since preview work isn't
  "pending for the Doc."
- Surface any discrepancies from step 4 and any releases you intentionally skipped (as normal text,
  outside the copy boxes).

Note: the connected Google Drive integration is **read-only** — there is no API to insert/edit an
existing Google Doc, and a plain-text insert wouldn't reproduce the native list styling anyway. So
the user copies the boxes themselves. Only attempt to write into the Doc if a real Google Docs edit
tool (or the browser extension) is available **and** the user explicitly asks for it.

## App JA — the mobile app (source: Slack, not GitHub)

App JA's repo (`erliamx/erlia-app`) has **no GitHub releases**, so the collector doesn't apply.
Instead: **which versions shipped** comes from a GitHub Actions workflow, and **the descriptive
text** comes from the developer's Slack posts. Treat App JA as another section of the same Google
Doc: it lives at the **top** of the Doc under `# App JA` / `# App Jalisco Alerta`.

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

The last documented version is the highest real `## vX.Y.Z` under the App JA section of the Doc
(skip the `## v2.. (...)` / `- Feature` stub). Add every shipped version newer than that, newest-first,
using the **deploy date** for the heading. **Versions are commonly skipped** (e.g. v2.22/2.25 never
deployed) — the workflow tells you exactly what shipped, so don't assume contiguous numbering.

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
so confirm there before you mark any version live, and gate every ` - Pendiente` removal on it (see
the ` - Pendiente` rule below).
- **Apple App Store** (the authoritative check — clean JSON, gives the live version **and** its
  release date):
  ```bash
  curl -s "https://itunes.apple.com/lookup?bundleId=mx.erlia.jal.ios&country=mx" \
    | python3 -c "import sys,json; a=json.load(sys.stdin)['results'][0]; print(a['version'], a['currentVersionReleaseDate'][:10])"
  ```
  (App Store id `6748151640`.) When this returns the version you're documenting, it **is** live —
  use `currentVersionReleaseDate` as the deploy date for the heading.
- **Google Play** (Android pkg `mx.erlia.jal.android`) has **no public version API**; scrape the
  details page and read the current-version token (heuristic — Google can change the structure):
  ```bash
  curl -s -A "Mozilla/5.0" "https://play.google.com/store/apps/details?id=mx.erlia.jal.android&hl=es&gl=US" \
    | grep -oE '\[\[\["[0-9]+\.[0-9]+\.[0-9]+"\]\]' | head -1
  ```
  Google Play is **informational only** — it does **not** gate ` - Pendiente` removal (Apple does).
- The store only reports the **currently-live** version (not historical per-version dates), so it's
  the source of truth for "is the newest announced version live yet?"; use the deploy workflow for
  dates of older versions. Single-store releases are rare, so assume iOS and Android ship together;
  in the uncommon case they diverge, keep ` - Pendiente` until the App Store lists it and flag it to
  the user rather than guessing a ` - Solo Android` / ` - Solo iOS` label.

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
  version's entry, mention every RC to the user, and keep updating that version's draft on each run
  until the user has pasted it into the Doc** — its content may still be changing.
- **A version is often announced here before it reaches the store.** #app-changelog gives the
  *notes*; the Slack post and the deploy workflow only mean the build was *cut/deployed*, **not** that
  the client can download it. Surface an announced version even if it's not live yet, but **flag its
  status** and mark it pending until the store confirms it.
  When an announced-but-unreleased version is added to the Doc, its heading carries a **` - Pendiente`**
  suffix (e.g. `## v2.27.0 (1 julio 2026) - Pendiente`) with the announcement date as placeholder.
- **The Apple App Store is the single source of truth for removing ` - Pendiente`. Remove it the
  moment the version appears there — and never one moment before.** On every subsequent run, look up
  the live App Store version (the `itunes.apple.com/lookup` command above):
  - If the store's live version is **not yet** the pending version → keep ` - Pendiente` as-is,
    regardless of what Slack, the deploy workflow, or Google Play say. A cut build, a green pipeline,
    or an Android-only rollout is **not** enough.
  - Once the App Store lists that version → drop ` - Pendiente` and set the heading date to the
    store's `currentVersionReleaseDate`. Hand the user the corrected heading.
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
- One bullet per distinct change; nested sub-bullets for enumerations (e.g. the Mundial content
  list — parent bullet ending in `:` then indented sub-bullets, emoji on the parent only).
- Heading `## vX.Y.Z (D mmmm aaaa)`; add ` - Solo Android` / ` - Solo iOS` only if the version is
  platform-specific. Use the production-deploy date; the announcement date is a placeholder. If the
  version is announced but not yet deployed to prod, append ` - Pendiente` and use the announcement
  date as placeholder (see the scope rules above for how it gets removed once the version ships).

(Note: older App JA entries already in the Doc were written in the warmer end-user voice — that's
legacy; new entries use this formal register.)

Present App JA exactly like step 6 (copy-boxes: heading line + dashless bullets). See
`references/changelog-style.md` for worked App JA before/after examples.

## Why drafts matter (don't skip this)

These repos publish **many draft releases** (often one per PR) interleaved with the real
published releases. The client only ever receives the **published, non-draft, non-prerelease**
ones. A published release usually bundles several draft-tagged commits, so its own release body
is often empty or lists only one PR — never trust it alone. The collector script handles this:
it keeps only published releases and diffs *previous-published-tag → this-published-tag*, which
captures everything that shipped. If you ever collect changes by hand, replicate that logic.
