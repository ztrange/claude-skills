# Why the 5a rollup filter is written that way

Read this before **editing** the filter, or when a rollup row looks wrong. A run does not need it.

Every mistake available here has one shape: **an absence of signal read as a positive answer.**
`[]`, `""` and a missing key all mean *ask again*, never *pass*.

## The clauses

- **The two row shapes have disjoint keys**, so a missing key reads as `null` and null-sniffing
  becomes an accidental type test. `gh`'s own export (`api/export_pr.go`) emits for a **CheckRun**:
  `__typename, name, workflowName, status, conclusion, startedAt, completedAt, detailsUrl` — no
  `state` at all; for a **StatusContext** (legacy commit status, e.g. an external provider):
  `__typename, context, state, targetUrl, startedAt` — no `status`, no `conclusion`, and the name
  lives in `context`. Branch on `__typename`, which is always present.
- **`.conclusion // .state` does not fall through.** jq's `//` falls through on `null` and `false`
  only, and an in-progress check run has `conclusion: ""`. Observed on
  ps-mutuus/mutuus-changelog#52: `{"name":"Site typecheck + build","status":"IN_PROGRESS","conclusion":""}`
  lands in an empty-string bucket that is not `FAILURE`, so it reads as fine. Gate on `status` first;
  look at `conclusion` only once `status == "COMPLETED"`.
- **`.state != null` means "this is a legacy status context", not "it finished".** A pending one is
  `state: "PENDING"`.
- An unrecognised `__typename` falls to the `else` branch with no `state` and lands in `pending`.
  Deliberate: unknown fails closed.

## The four enums

| Enum | Values | Terminal / failing |
|---|---|---|
| `CheckStatusState` | `REQUESTED QUEUED IN_PROGRESS COMPLETED WAITING PENDING` | `COMPLETED` is the only terminal one — five of six are still running |
| `CheckConclusionState` | `FAILURE TIMED_OUT CANCELLED ACTION_REQUIRED STARTUP_FAILURE STALE` fail; `SUCCESS NEUTRAL SKIPPED` pass | failing is more than `FAILURE` |
| `StatusState` | `EXPECTED ERROR FAILURE PENDING SUCCESS` | only the last three are terminal, so `PENDING`/`EXPECTED` count as pending |

## Why `total > 0` guards the loop exit

Without it the 5c loop terminates instantly on the post-force-push `[]` — which is exactly how a
hand-written poll passed a PR whose checks had not started. `[]` is what GitHub returns for a minute
or two after a force-push, while it re-associates workflow runs with the new head. Observed on #52
right after a step-4 push: rollup `[]` and `gh pr checks 52` printing
`no checks reported on the 'claude/gh-path-helper' branch`, while a `PR checks` run was already
queued for that exact head sha.

## Provenance, and what is not observed

- The `StatusContext` half of the filter is **derived, not observed**: fields from
  `api/export_pr.go`, terminal/failing values from the `StatusState` GraphQL enum, but no live legacy
  status context has been seen through it. Only the `CheckRun` half is observed
  (ps-mutuus/mutuus-changelog#52, and a 37-row live rollup on cli/cli#14334). If a repo's CI posts
  commit statuses rather than check runs, read the raw rows once before trusting the summary.
- `gh run list` sees GitHub Actions only, so an external provider that posts commit statuses appears
  in neither it nor the rollup until it registers. That is why "no CI" needs a settle window and
  gets said in the report as a conclusion drawn from an absence.
- 6a's "did readying start new checks?" test counts GitHub Actions runs for the head sha, so a
  `ready_for_review` trigger on an external provider is invisible to it, and 30s is a settle window,
  not a guarantee. 6b's rollup re-read still refuses anything pending by then. Tested against a
  stubbed `gh`, not a live draft PR.
- `gh pr checks` exit `8` (pending) is documented but was not observed here.
