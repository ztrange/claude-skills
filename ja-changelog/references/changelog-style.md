# Changelog style guide (Spanish, client-facing)

This format is derived from the client's existing changelog Google Doc — **match it exactly**.
When in doubt, open the Doc (see SKILL.md for the id) and imitate the most recent real entries
for that same app.

## Where each app lives in the Doc

The Doc is organized **by app, then by version newest-first**. Each app has two stacked H1s:
a codename and a full name. Append new versions at the **top** of the app's section.

- `# EDL` / `# Earth Data Lab`
- `# SIGEM` / `# Sistema de Gestión de Emergencias`
- `# Gabinete` / `# JA Gabinete`
- (`# App Jalisco Alerta` is the mobile app — NOT in scope for this skill.)

## Entry format

```markdown
## vX.Y.Z (D mmmm aaaa)
- <cambio en lenguaje claro>
- <cambio en lenguaje claro>
```

- Heading: `## ` + version tag + ` (` + date + `)`. Keep the real tag (e.g. `v2.268.0`).
- **Date format: `18 junio 2026`** — day number, a space, the Spanish month in **lowercase**,
  a space, the year. No "de", not numeric. Months: enero, febrero, marzo, abril, mayo, junio,
  julio, agosto, septiembre, octubre, noviembre, diciembre.
- **Flat bullet list** — no themed subsection titles.
- **One `- ` bullet per distinct change.** Do not enumerate several separate changes inside one
  bullet with commas — that breaks the Doc's convention. When a single feature genuinely has
  several sub-parts worth listing, write a parent bullet ending in `:` and nest the parts as
  indented sub-bullets (the Doc does this), e.g.:
  ```markdown
  - Se agrega una experiencia de inspecciones optimizada para celular:
      - Listado de inspecciones
      - Detalle de inspección
      - Estatus y reportes de inspección
      - Creación y edición de visitas
  ```
  Commas are fine *within* one coherent sentence, just not as a substitute for separate bullets.
- **Merge same-day releases into one entry.** When two or more published releases share the same
  publish date, combine them into a single entry with a version-range heading (lowest–highest), the
  way the Doc does (e.g. `v0.38.2-v0.38.3 (25 junio 2026)` or `v0.34.0-v0.36.0 (15 junio 2026)`),
  and list all of their bullets together under that one heading. Releases on **different** days stay
  as separate entries. Determine the date from each release's `publishedAt` (the collector provides it).
- A release may carry a qualifier after the date when relevant, joined with ` - ` (e.g.
  `## v2.15.0 (7 abril 2026) - Solo Android`). Only add one if it genuinely applies.

## Voice: impersonal "Se…", value first

The Doc's bullets are full sentences in impersonal Spanish, overwhelmingly starting with **"Se "**:

- Features: `Se agrega…`, `Se incorpora…`, `Se habilita…`, or a noun phrase (`Nuevo filtro…`,
  `Mapa de pronóstico del tiempo`).
- Improvements: `Se mejora…`, `Se ajusta…`, `Se optimiza…`.
- Bug fixes: `Se corrige el error que causaba que…` / `Se corrige el defecto que provocaba que…`.

Lead with the capability or benefit for the client (Gobierno de Jalisco), not the implementation.
Keep it concrete but readable. Avoid in the final text: PR numbers, branch names, commit hashes,
file paths, table names, and the internal ticket prefixes (MON:, COM:, VEH:, INCID:…).

## Internal / technical changes

The Doc does include developer-facing items, but per the team's preference keep them **condensed
into a single short sentence at the end** of the version rather than itemizing each one — and
without a comma-list of the internal items, e.g.:

`- Se realizan diversas mejoras técnicas e internas para sostener las nuevas funciones.`

Only break internal work into its own bullet if an item has real client impact (e.g. a rollback
capability the client asked for). Pure CI bumps, lint, tests, and dependency upgrades fold into
that one line or are omitted.

## Before / after (raw change → Doc-style bullet)

**Example 1 — feature**
Input (PR title): `MON: Lista de riesgos detectados`
Output: `- Se agrega una lista de riesgos detectados en el monitor, para identificar de un vistazo las zonas que requieren atención.`

**Example 2 — performance made client-relevant**
Input (PR title): `COM: Optimizar uso de grid al mandar notificaciones`
Output: `- Se mejora la velocidad y confiabilidad del envío de notificaciones, especialmente al alertar zonas extensas.`

**Example 3 — bug fix (use the "Se corrige el error que causaba que…" frame)**
Input: `MON, COM: Al retroceder en el tiempo, casi todas las estaciones salen desconectadas`
Output: `- Se corrige el error que causaba que, al consultar momentos anteriores en el histórico, casi todas las estaciones aparecieran como desconectadas.`

**Example 4 — feature with client framing from ClickUp**
Input: `feat: rating notifications` (+ ClickUp "COM: Endpoint para contabilizar calificación de notificaciones")
Output: `- Se agrega la posibilidad de que la ciudadanía califique las notificaciones recibidas, y se contabilizan esas calificaciones para medir su utilidad.`

**Example 5 — SIGEM domain**
Input: `VEH: Excluir kilometraje y prox mtto, de vehículos de tipo incompatible`
Output: `- Se omiten el kilometraje y el próximo mantenimiento en los vehículos de tipo incompatible, evitando datos que no aplican y posibles confusiones.`

**Example 6 — collapse internal work (one sentence, no comma-list)**
Input: `feat: github actions - latest versions`, `fix: add new indexes`, `fix: metadata columns`
Output: `- Se realizan diversas mejoras técnicas e internas para sostener las nuevas funciones.`

**Example 7 — split a comma enumeration into nested sub-bullets**
Input (PRs): `INSP MOVIL: Listado de inspecciones`, `INSP MOVIL: Detalle inspección`, `INSP MOVIL: Estatus y reportes`, `INSP MOVIL: Crear / editar visita`
Bad (one comma-joined bullet): `- Se agrega inspecciones móvil: listado, detalle, estatus y reportes, y crear/editar visitas.`
Good:
```markdown
- Se agrega una experiencia de inspecciones optimizada para celular:
    - Listado de inspecciones
    - Detalle de inspección
    - Estatus y reportes de inspección
    - Creación y edición de visitas
```

## App Jalisco Alerta (mobile app) — elevate the tone

The source is the developer's Slack store-text (see SKILL.md "App JA"), written for **end users**
("Ahora puedes…, disfruta…, para ti"). Our Doc's audience is **non-technical product stakeholders**,
so App JA uses the **same formal, impersonal register as the admin apps** — elevate the tone,
don't copy the end-user marketing voice. Headings/date format are the same as the rest of the Doc
(`## vX.Y.Z (D mmmm aaaa)`), optional ` - Solo Android` / ` - Solo iOS` suffix if platform-specific.

**Example A — Slack store-text (end-user tone) → stakeholder bullets (formal)**
Input (Slack):
> "Ahora puedes calificar las alertas que recibes y enviarnos comentarios o sugerencias directamente
> desde la app. También renovamos el contenido del módulo del Mundial 2026 y mejoramos el mapa.
> Además, ampliamos el contenido en todos los idiomas e incluimos mejoras de rendimiento."
Output (elevated register):
```markdown
- Se agrega la posibilidad de calificar las alertas recibidas.
- Se agrega el envío de comentarios o sugerencias directamente desde la aplicación.
- Se renueva el contenido del módulo del Mundial 2026 con una experiencia más interactiva.
- Se mejora el mapa para facilitar la visualización del pronóstico del tiempo y de la información.
- Se amplía el contenido disponible en todos los idiomas compatibles.
- Se realizan mejoras generales de rendimiento y estabilidad.
```
Note the elevation: Slack "Ahora puedes calificar…" → "Se agrega la posibilidad de calificar…".

**Example B — enumeration → nested sub-bullets (real Doc pattern)**
```markdown
- Se incorpora un nuevo módulo sobre el sismo en Venezuela:
    - Descripción de lo ocurrido
    - Recomendaciones útiles
    - Enlaces oficiales para brindar apoyo
```

So the whole Doc reads in one consistent formal register — admin apps and App JA alike use
`Se agrega… / Se incorpora… / Se mejora… / Se corrige el error que causaba que…`.

## Common pitfalls

- Don't list every commit — a release with 12 commits often maps to 3–5 client bullets.
- **Don't default to "Se agrega."** Distinguish a *new* thing from a *change* to an existing one. If
  every changed file is `Modified` (none `Added`), or the ClickUp task's verb is `Cambiar/Migrar/
  Ajustar`, it's a change → `Se cambia/Se mejora…`, never `Se agrega una vista/función…`. Reserve
  `Se agrega/Se incorpora…` for genuinely new capabilities (new screen/module/endpoint = `Added`
  files). E.g. `MON: Cambiar fuente de datos para riesgos detectados` → "Se cambia la fuente de datos
  del monitor para usar los riesgos registrados", NOT "Se agrega la vista de riesgos registrados".
- Don't invent benefits. If a change's client value is unclear, inspect the diff or the ClickUp
  task; if still unclear, fold it into the internal-improvements line rather than guessing.
- Don't translate commit messages literally — translate the *intent*.
- Mirror the Doc's exact date format and "Se…" phrasing; a mismatched style is a tell that it
  wasn't written by the team.
