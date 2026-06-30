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
| **App JA** | Consumer mobile app — receives EDL's alerts | **Slack** (dev posts) | — | — | `901316895020` | `v2.x` |

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

App JA has no usable GitHub release flow here; instead the **developer posts each version's "texto
para tiendas" (app-store release text) in Slack**. Treat App JA as another section of the same
Google Doc: it lives at the **top** of the Doc under `# App JA` / `# App Jalisco Alerta`.

### Find the release messages
- Slack channel **#app-jalisco-alerta** (id `C099DKW3MV0`), author **Diego R Galindo** (`U099H6TPS04`).
- A **relevant message** = a version number (`version 2.26.0` / `Versión 2.21.0`) followed by a
  fenced ```code block``` of consumer-facing prose. **Skip** feedback-form entries, screenshots, and
  technical discussion threads — they are not release texts.
- Read them with `slack_read_channel` on the channel, or `slack_search_public` with
  `from:<@U099H6TPS04> in:<#C099DKW3MV0>`. **Versions are sometimes skipped** (not every build ships
  a store text), so don't assume contiguous numbering — if a version between the last documented one
  and the latest has no message, it was likely skipped; note it rather than inventing content.

### Scope
Same rule as the other apps: the last documented version is the highest real `## vX.Y.Z` under the
App JA section of the Doc (skip the `## v2.. (...)` / `- Feature` stub). Add only newer messages,
newest-first.

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
