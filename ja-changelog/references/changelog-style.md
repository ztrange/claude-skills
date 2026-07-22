# Changelog style guide (Spanish, internal stakeholders)

**Audience:** internal Jalisco Alerta stakeholders who **know the project deeply** (one is the
Product Owner) — non-developers, but not the general public. Write **precise and specific** bullets
that name the actual modules/screens/features, don't over-simplify, and don't hide technical work.
See SKILL.md's audience note at the top.

This format matches the existing changelog in the `ja-changelog` DB / public site. **Match the most
recent real entries for that same app.** Every bullet carries (1) a **category emoji** prefix and (2)
treats **standalone technical changes** as first-class ⚙️ entries (both described below).

## Where each app's data lives

Each app has its own data folder in the `ja-changelog` DB — `data/<slug>/<YYYY-MM>.json` — holding
that month's releases newest-first (`write_release.py` prepends new releases). The public site
renders one section per app. **All four apps are in scope**, including the mobile app:

- `edl` (Earth Data Lab)
- `sigem` (Sistema de Gestión de Emergencias)
- `gabinete` (JA Gabinete)
- `app-ja` (App Jalisco Alerta — the mobile app)

## Entry format

```markdown
## vX.Y.Z (D mmmm aaaa)
- <emoji> <cambio en lenguaje claro>
- <emoji> <cambio en lenguaje claro>
```

Each bullet is prefixed with a **category emoji** (legend below) + a space, before the "Se…". The
`## vX.Y.Z (fecha)` above is how a release **renders** on the site; you actually write only the
bullets (in `flat.md`) and pass the version/date to `write_release.py`.

- Version + date become `write_release.py`'s `--version` (keep the real tag, e.g. `v2.268.0`) and
  `--date` (ISO `YYYY-MM-DD`); the site renders the date in Spanish.
- **Date format: `18 junio 2026`** — day number, a space, the Spanish month in **lowercase**,
  a space, the year. No "de", not numeric. Months: enero, febrero, marzo, abril, mayo, junio,
  julio, agosto, septiembre, octubre, noviembre, diciembre.
- **Flat bullet list** — no themed subsection titles.
- **One `- ` bullet per distinct change.** Do not enumerate several separate changes inside one
  bullet with commas — that breaks the one-bullet-per-change convention. When a single feature
  genuinely has several sub-parts worth listing, write a parent bullet ending in `:` and nest the
  parts as indented sub-bullets, e.g.:
  ```markdown
  - Se agrega una experiencia de inspecciones optimizada para celular:
      - Listado de inspecciones
      - Detalle de inspección
      - Estatus y reportes de inspección
      - Creación y edición de visitas
  ```
  Commas are fine *within* one coherent sentence, just not as a substitute for separate bullets.
- **Merge same-day releases into one release.** When two or more published releases share the same
  publish date, combine them into a single release with a version-range value (lowest–highest, e.g.
  `v0.38.2-v0.38.3` or `v0.34.0-v0.36.0`), and list all of their bullets together. Releases on
  **different** days stay as separate releases. Determine the date from each release's `publishedAt`
  (the collector provides it).
- A release may carry a qualifier (`write_release.py --note "Sólo Android"`) shown next to the
  version on the site. Only add one if it genuinely applies.

## Voice: impersonal "Se…", value first

The bullets are full sentences in impersonal Spanish, overwhelmingly starting with **"Se "**. Each is
prefixed by one **category emoji**:

| Emoji | Category | Frame |
|-------|----------|-------|
| ✨ | **Nueva funcionalidad** — genuinely new capability | `Se agrega…`, `Se incorpora…`, `Se habilita…`, or a noun phrase (`Nuevo filtro…`) |
| 🔧 | **Mejora o cambio** to something existing | `Se mejora…`, `Se cambia…`, `Se ajusta…`, `Se optimiza…` |
| 🐛 | **Corrección** (bug fix) | `Se corrige el error que causaba que…` / `Se corrige el defecto que provocaba que…` |
| ⚙️ | **Técnico** — standalone endpoint/refactor/component/infra change not covered by another entry | `Se agrega el endpoint…`, `Se refactoriza…`, `Se reestructura…` |

Pick the emoji by what the change *is*, not by its wording: a reworked existing screen is 🔧, not ✨;
reserve ✨ for genuinely new capabilities (Added files / new screen-module-endpoint). On a parent
bullet with nested sub-bullets, the emoji goes on the **parent only**.

Lead with what changed, and be specific — you may name the concrete module/screen/feature since the
audience knows the project. Avoid in the final text: PR numbers, branch names, commit hashes,
file paths, table names, and the internal ticket prefixes (MON:, COM:, VEH:, INCID:…).

## Internal / technical changes

Technical work is legitimate content — the audience understands the project. Give each **noteworthy,
standalone** technical change its own clear **⚙️** bullet (a new endpoint, a refactor, a component or
infra enhancement). **Do not** bundle them into one generic "Se realizan diversas mejoras técnicas e
internas…" line — that was the old rule; retire it.

Two limits keep it from becoming a git log:

1. **Only what isn't already covered.** A ⚙️ bullet earns its place only if the change isn't already
   represented by another entry. If it's the plumbing behind a ✨/🔧/🐛 item you're already listing
   (e.g. the endpoint that powers a feature bullet), **omit it** — it's redundant.
2. **Trivia still drops.** Pure CI/pipeline bumps, dependency upgrades, lint/formatting, and
   test-only changes are omitted, or at most collapsed into a **single** short ⚙️ line — never a
   comma-enumeration.

Write ⚙️ bullets clearly, not cryptically: `⚙️ Se agrega el endpoint de vista web para compartir
notificaciones` beats `⚙️ Nuevo handler de webview`.

## Before / after (raw change → changelog bullet)

**Example 1 — ✨ new feature**
Input (PR title): `MON: Lista de riesgos detectados`
Output: `- ✨ Se agrega una lista de riesgos detectados en el monitor, para identificar de un vistazo las zonas que requieren atención.`

**Example 2 — 🔧 improvement (performance made concrete)**
Input (PR title): `COM: Optimizar uso de grid al mandar notificaciones`
Output: `- 🔧 Se mejora la velocidad y confiabilidad del envío de notificaciones, especialmente al alertar zonas extensas.`

**Example 3 — 🐛 bug fix (use the "Se corrige el error que causaba que…" frame)**
Input: `MON, COM: Al retroceder en el tiempo, casi todas las estaciones salen desconectadas`
Output: `- 🐛 Se corrige el error que causaba que, al consultar momentos anteriores en el histórico, casi todas las estaciones aparecieran como desconectadas.`

**Example 4 — ✨ feature with framing from ClickUp**
Input: `feat: rating notifications` (+ ClickUp "COM: Endpoint para contabilizar calificación de notificaciones")
Output: `- ✨ Se agrega la posibilidad de que la ciudadanía califique las notificaciones recibidas, y se contabilizan esas calificaciones para medir su utilidad.`
Note: the "Endpoint para contabilizar…" is the plumbing behind this feature — it does **not** get its
own ⚙️ bullet, because it's already represented here.

**Example 5 — 🔧 change to existing behavior (SIGEM domain)**
Input: `VEH: Excluir kilometraje y prox mtto, de vehículos de tipo incompatible`
Output: `- 🔧 Se omiten el kilometraje y el próximo mantenimiento en los vehículos de tipo incompatible, evitando datos que no aplican y posibles confusiones.`

**Example 6 — ⚙️ standalone technical change (not covered by any other entry)**
Input: `feat: add notification web view endpoint with SIGEM preview proxy and cache` (no user-facing entry lists it)
Output: `- ⚙️ Se agrega un endpoint de vista web para notificaciones, que permite mostrar la vista previa al compartir enlaces en WhatsApp y Telegram.`
Contrast: pure trivia (`chore: bump github actions`, `fix: add new indexes`, lint) is **omitted**, or
at most one short `- ⚙️ Se realizan ajustes técnicos internos.` — never a comma-list.

**Example 7 — split a comma enumeration into nested sub-bullets (emoji on the parent only)**
Input (PRs): `INSP MOVIL: Listado de inspecciones`, `INSP MOVIL: Detalle inspección`, `INSP MOVIL: Estatus y reportes`, `INSP MOVIL: Crear / editar visita`
Bad (one comma-joined bullet): `- ✨ Se agrega inspecciones móvil: listado, detalle, estatus y reportes, y crear/editar visitas.`
Good:
```markdown
- ✨ Se agrega una experiencia de inspecciones optimizada para celular:
    - Listado de inspecciones
    - Detalle de inspección
    - Estatus y reportes de inspección
    - Creación y edición de visitas
```

## App Jalisco Alerta (mobile app) — elevate the tone

The source is the developer's Slack store-text (see SKILL.md "App JA"), written for **end users**
("Ahora puedes…, disfruta…, para ti"). Our audience is the **internal project stakeholders** (they
know the project; one is the Product Owner), so App JA uses the **same formal, impersonal register and
category emojis as the admin apps** — elevate the tone, don't copy the end-user marketing voice.
Version/date/emoji format is the same as the admin apps; add an optional `--note "Sólo Android"` /
`"Solo iOS"` only if platform-specific. App JA store text rarely surfaces standalone ⚙️ technical
items, so its bullets are usually ✨/🔧/🐛.

**Example A — Slack store-text (end-user tone) → stakeholder bullets (formal, with emojis)**
Input (Slack):
> "Ahora puedes calificar las alertas que recibes y enviarnos comentarios o sugerencias directamente
> desde la app. También renovamos el contenido del módulo del Mundial 2026 y mejoramos el mapa.
> Además, ampliamos el contenido en todos los idiomas e incluimos mejoras de rendimiento."
Output (elevated register):
```markdown
- ✨ Se agrega la posibilidad de calificar las alertas recibidas.
- ✨ Se agrega el envío de comentarios o sugerencias directamente desde la aplicación.
- 🔧 Se renueva el contenido del módulo del Mundial 2026 con una experiencia más interactiva.
- 🔧 Se mejora el mapa para facilitar la visualización del pronóstico del tiempo y de la información.
- 🔧 Se amplía el contenido disponible en todos los idiomas compatibles.
- 🔧 Se realizan mejoras generales de rendimiento y estabilidad.
```
Note the elevation: Slack "Ahora puedes calificar…" → "✨ Se agrega la posibilidad de calificar…".

**Example B — enumeration → nested sub-bullets (emoji on the parent only)**
```markdown
- ✨ Se incorpora un nuevo módulo sobre el sismo en Venezuela:
    - Descripción de lo ocurrido
    - Recomendaciones útiles
    - Enlaces oficiales para brindar apoyo
```

So the whole changelog reads in one consistent formal register — admin apps and App JA alike use
`✨/🔧/🐛/⚙️` + `Se agrega… / Se incorpora… / Se mejora… / Se cambia… / Se corrige el error que causaba que…`.

## Common pitfalls

- Don't list every commit — a release with 12 commits often maps to 3–5 bullets.
- **Don't default to "Se agrega." / ✨.** Distinguish a *new* thing from a *change* to an existing
  one. If every changed file is `Modified` (none `Added`), or the ClickUp task's verb is `Cambiar/
  Migrar/Ajustar`, it's a change → 🔧 `Se cambia/Se mejora…`, never ✨ `Se agrega una vista/función…`.
  Reserve ✨ `Se agrega/Se incorpora…` for genuinely new capabilities (new screen/module/endpoint =
  `Added` files). E.g. `MON: Cambiar fuente de datos para riesgos detectados` → "🔧 Se cambia la
  fuente de datos del monitor para usar los riesgos registrados", NOT "✨ Se agrega la vista…".
- **Don't repeat covered work as a ⚙️ bullet.** A technical change that's just the plumbing behind a
  ✨/🔧/🐛 entry you already wrote does not get its own ⚙️ line — only *standalone* technical changes do.
- Don't invent benefits. If a change's value is unclear, inspect the diff or the ClickUp task; if
  still unclear, ask the user rather than guessing.
- Don't translate commit messages literally — translate the *intent*.
- Mirror the exact date format and "Se…" phrasing, and put exactly one category emoji at the start of
  each bullet; a mismatched style is a tell that it wasn't written by the team.
