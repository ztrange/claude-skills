# Design principles — architecture, tests, order of work, documentation

The conventions `house-style` applies. Read this when designing a seam, writing tests, standing up a
new project, or arguing about direction. The codebase still wins on style: these steer what is newly
designed, and they are not a mandate to migrate working code.

## Architecture

- **Make the invariant structural, not documented.** A comment warning callers what to remember is a
  bug with a note attached. Prefer the shape where the mistake cannot be expressed: an operation that
  names what it changes rather than taking an options bag, so there is no field a caller can omit.
- **Targeted writes over full replaces** at every persistence seam. Read-edit-put makes every field
  the caller's problem, and the first one who forgets a field drops it silently — while a test
  asserting "the row still looks right" passes anyway.
- **Privacy is the enforcement.** A layer that asks not to be bypassed is a convention, and
  conventions lose. Don't re-export the raw client from the repository index: a route that cannot
  *name* the table cannot issue its own query.
- **Containment runs both ways.** Stopping callers reaching in is half a seam; the other half is the
  implementation's vocabulary not leaking out. The guarded writer raises what its condition *means*,
  because only the writer knows what it asserted — the same driver error is a 409 on one write, a 404
  on another, a 410 on a third. `ja-changelog` instead had ten route files each testing a raw AWS
  error name, four dialects for "the conditional write lost".
- **One copy of the data.** A second copy of a judgement competes with it, and a stale copy is worse
  than none. Where something a person decided cannot be re-derived, that argues for retaining the
  real store, not a hand-maintained mirror.
- **Configuration that steers nothing is worse than none** — a value no code reads will be trusted by
  the next person. Either wire it, or say where it is displayed that it is inert.
- **One schema is the contract; types derive from it.** Not a hand-kept type beside a hand-kept
  validator beside a hand-kept OpenAPI file. In `expense-tracking` the Zod schemas in `shared` are
  the source: the server validates with them, docs generate from them, the frontend imports the
  inferred types. Test in any language: *can two copies of this contract disagree?* Fixtures and mock
  handlers build from the schemas too — a hand-written fixture is a third copy and drifts first.
- **Depth, seams and adapters**, in that vocabulary — call the Skill tool with `"codebase-design"`
  for the glossary. One adapter means a hypothetical seam; two mean a real one.
- **Environment is selected by explicit input, and the tooling refuses the wrong one** — the deploy
  path fails closed on a missing or mismatched target rather than defaulting to something plausible.
- **Siblings don't import each other.** Each owns its manifest; the coupling is a path, not an import.

## Tests

**Test-first, and the test has to earn it.** Red before green, and the red has to fail *for the right
reason* — not a typo, a missing import, or an unwired fixture. A test nobody has watched fail is not
known to test anything.

- **Assert public behaviour, not internals.** A test reaching past the interface describes the
  implementation and breaks on the refactor that was supposed to be safe.
- **Generality comes from triangulation.** Don't write the general solution because you can see it;
  let the next case force it. The shortcut is how you get a general implementation nothing tests.
- **Spend behaviour specs on rule-dense modules** — simple inputs and outputs, a lot of logic
  between. A spec on a pass-through is ceremony.
- **Verification that cannot rubber-stamp.** Whatever confirms the test is honest should not have seen
  the reasoning that produced it — the `veri` idea, where a blind leaf gets the test and the spec but
  never the author's justification.
- **Assert the absence when the bug is an omission.** Where the failure is "a field got dropped",
  assert it does *not* happen. A positive assertion about the end state passes happily on the day the
  caller happened to remember.
- **Snapshot the surface that drift attacks** — the route table with its auth tier, the public
  exports — and derive counts from it with a command instead of restating them in prose. Two people
  each correctly adding one still merge to a wrong total.
- **Know what the build does not check, and put a test in the gap.** Packaging proves packaging, never
  that the code runs: where a directory ships as-is with no bundler and no typecheck, a misspelled
  relative import synths clean, deploys green and 500s at cold start. One test that imports the real
  module graph and asserts the entry point is a function stands between a typo and an outage.
- **A migration has an oracle** — the old system's output is the acceptance test: same inputs, same
  numbers, and the diff is the bug list.
- **Mock at the network boundary, not at the client.** MSW intercepts the transport, so the code under
  test uses its real client, serialisation and error paths; stubbing the client tests the stub. **No
  test reaches a real service**, and a test that needs one says the seam is missing.
- **A coverage number nothing enforces is decoration.** A threshold that fails CI, set where the suite
  actually is and raised deliberately; a comfortable number teaches the team to route around it.
- **One runner, layers above it.** Vitest for unit and component; Playwright is the acceptance layer,
  split off by what it proves — a real browser, real navigation — not by taste. A second runner in the
  *same* layer is a cost with no payer; where a project already has one, follow the project.

## Order of work on a new project

- **A walking skeleton with green CI before any feature** — typecheck, lint, test, build, e2e passing
  on an empty app, first commit. Until green is reachable a failing test is ambiguous: nobody can tell
  the red you wrote from the red the pipeline was already in, and red-before-green stops meaning
  anything.
- **The skeleton carries the smoke test** — the one that imports the real entry point and asserts it
  loaded, from commit #1 rather than after the first cold-start 500.
- **Logging is day-one work, behind a seam.** Structured logs (pino is the current pick) through one
  module the app calls, not `console.log` at call sites. Logging added after an incident is designed
  by hindsight. Put the error-tracker and telemetry adapter in at the same time, dormant — the seam is
  what makes activating it a config change.
- **Local first while requirements are still moving.** Run the whole thing on the machine behind
  storage and config seams; add the cloud adapter when a real need forces it. The default is still AWS
  and serverless — this is about *when*, not *whether* — and the two adapters are what make that seam
  real rather than hypothetical. Record the deferral as an ADR.

## Documentation

- **`CLAUDE.md` is what exists and why** — what you would otherwise learn by breaking something. Not
  the queue: unfinished work and decisions waiting on a human go in `TODO.md`. A TODO that accumulates
  finished work stops being read; a CLAUDE.md that accumulates plans stops being trusted.
- **The glossary is `CONTEXT.md`, and it lands before the first feature.** Decisions go in
  `docs/adr/` — the ones from a real trade-off that would look arbitrary without it. Call the Skill
  tool with `"domain-modeling"` when either needs work.
- **A line that can go stale points at its authority instead of asserting the value.** Not "nine gated
  routes" but "read the count off the route snapshot", with the command. Any count in prose is a claim
  that will be wrong later and confidently cited in the meantime.
- **Keep the corrections, with the reasoning that made them plausible.** A wrong symbol invites a
  correction; a wrong symbol with a convincing rationale invites someone to change the code to match.
- **Commands in the file have been run**, from the directory the line names, doing what it claims.

