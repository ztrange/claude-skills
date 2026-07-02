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
---

# Jalisco Alerta — Changelog Generator

Produce a **client-facing changelog in Spanish** that communicates the *value delivered* to
the client (Gobierno de Jalisco), not a raw git log. The audience is non-technical
stakeholders: each bullet should answer "what can the client now do, or what got better?"

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

## Workflow

Run these steps **per app**. Work app-by-app so a failure in one doesn't lose the others.

### 1. Determine scope (what's new since the last changelog)

The default scope is **only releases newer than what's already documented**. Find the last
documented version per app from the changelog Google Doc:

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
`compareRange`, merged `prs` (number, branch, title), `commits`, and `changedFiles`.

### 3. Interpret what each release actually does

For each release, read the PR titles, commit subjects, and changed-file paths to understand
the substance. The PR title is usually the best signal. When a change is ambiguous or
high-impact and the title is terse (e.g. `fix: default fields`), inspect the actual diff:

```bash
git -C <repo_path> log <compareRange> --oneline
git -C <repo_path> show <commit_hash>        # or: git diff <compareRange> -- <path>
```

Filter out noise the client doesn't care about: pure CI/pipeline bumps, dependency upgrades,
lint/formatting, test-only changes, infra refactors with no user-visible effect. Tech-debt and
internal items belong at most in a brief "técnico/interno" note, not as headline value.

**Also exclude — even though it shipped — anything the client can't actually see yet:**
- **Feature-flagged-off in production.** If a feature is gated behind a production feature flag
  (look for PRs like "hide … in production via feature flag") or its ClickUp task is still open
  (not done/ready), **don't mention it until it's live for the client**. Note it to the user as
  excluded so they know it's pending, not lost.
- **Work that belongs to a different app.** Some backend changes in one repo actually support
  another app. Notably, **"Venezuela" changes in EDL** are backend for an **App JA** disaster-relief
  feature (*acopio de víveres para desastre natural*) — they do **not** belong in EDL's client
  changelog; they'll surface under App JA when that feature ships. Route such changes to the right
  app or omit.

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
- Spanish, impersonal, value-first: bullets start with **"Se agrega…/Se mejora…/Se corrige el
  error que causaba que…"**. Lead with the benefit, not the implementation.
- **One bullet per distinct change.** Never pack several distinct changes into a single bullet
  joined by commas — that breaks the Doc's convention. If a single feature has several sub-parts
  worth listing (e.g. a new module with multiple screens), use a parent bullet ending in `:` with
  **nested sub-bullets**, the way the Doc does. Commas are fine only inside one coherent sentence,
  not as a way to enumerate separate items.
- Merge several commits into one bullet only when they're genuinely one change.
- No PR numbers, branch names, or English commit jargon in the body.
- Condense internal/CI/tech-debt work into a **single closing bullet** ("Se realizan diversas
  mejoras técnicas e internas para sostener las nuevas funciones."), or omit if trivial. Keep it
  as one short sentence — don't enumerate the internal items with commas.

### 6. Present for review — do NOT write a file

**Never save a draft file.** Output the changelog directly in the conversation, formatted so the
user can copy each piece straight into Google Docs (where headings and bullets are applied by the
Doc, not by Markdown). The user pastes manually, so:

- For **each version**, emit **two separate fenced code blocks** (each gets its own copy button):
  1. The **heading line only**: `vX.Y.Z (D mmmm aaaa)` — no `##`, no leading dash.
  2. The **bullets** for that version, **with NO leading `- ` markers** (one change per line), so
     they don't collide with the Doc's automatic bullets. Indent nested sub-items with spaces.
- Group these under a plain-text label per app (`# Codename` / `# Full Name`), versions newest-first.
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
- **A version is often announced here before it deploys to production.** #app-changelog gives the
  *notes*; the Deploy-Android-production workflow (above) gives the authoritative *ship status/date*.
  Surface an announced version even if it's not in prod yet, but **flag its prod status** (shipped vs
  pending) — use the real deploy date once it ships; the announcement date is only a placeholder.
- **If a shipped version has no store text** (e.g. hotfix v2.26.1), derive one concise client-facing
  line from its commits (compare the rc run's `headSha` against the previous version's via
  `gh api repos/erliamx/erlia-app/compare/<prevSha>...<thisSha>`), or a generic stability line.

### Reformat — the App JA voice is warmer than the admin apps
The dev writes flowing second-person paragraphs; the Doc's App JA section is **more
consumer-marketing** than the admin sections. Convert the prose into Doc-style bullets:
- **Lead user-facing features** with "Ahora puedes…", "Ahora la app…", or first-person-plural
  "Renovamos…/Mejoramos…/Agregamos…/Ampliamos…", keeping the benefit clause ("…para una experiencia
  más clara").
- Use impersonal "Se corrige… / Se agrega…" for **fixes and internal/stability** items.
- One bullet per distinct change; use nested sub-bullets for enumerations (e.g. the Mundial content
  list — parent bullet ending in `:` then indented sub-bullets).
- Heading `## vX.Y.Z (D mmmm aaaa)`; add ` - Solo Android` / ` - Solo iOS` **only** if the post says
  the version is platform-specific. The date is the store-release date — use the Slack post date as a
  proxy and flag it for the user to confirm.

Present App JA exactly like step 6 (copy-boxes: heading line + dashless bullets). See
`references/changelog-style.md` for worked App JA before/after examples.

## Why drafts matter (don't skip this)

These repos publish **many draft releases** (often one per PR) interleaved with the real
published releases. The client only ever receives the **published, non-draft, non-prerelease**
ones. A published release usually bundles several draft-tagged commits, so its own release body
is often empty or lists only one PR — never trust it alone. The collector script handles this:
it keeps only published releases and diffs *previous-published-tag → this-published-tag*, which
captures everything that shipped. If you ever collect changes by hand, replicate that logic.
