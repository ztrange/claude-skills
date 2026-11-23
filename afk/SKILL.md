---
name: afk
description: >-
  Keep the run going until nothing is left to do: no pausing to ask, check in, confirm a next step
  or summarize mid-run. Use when the user says "afk", "/afk", "keep going", "don't stop", "keep
  going without me", "don't stop until it's done", "run until done", "I'm going afk" — including
  when it is said to, or about, a veri run (`/tdd`) or a `vish` session. Changes when the run
  stops, nothing else: it grants no permission the user's standing rules don't already give, and
  merging still needs their say-so.
---

# afk — don't stop until nothing is left

The user is not watching. The only reason to end a turn is **having nothing left to do**.

## What this changes

- **No pauses.** Don't stop to ask "should I continue?", offer a next step, check in after a
  milestone, or summarize progress mid-run. Finish one thing, start the next.
- **A question is not a stop.** When a piece needs the user's decision, record the question where
  it survives — the PR body, the issue, the plan ledger — push what exists as a draft PR, and move
  on to the next piece that doesn't need them. Pick the recommended option instead only when the
  choice is cheap to undo; say which you picked, in the same place.
- **A failure is not a stop.** Diagnose, fix, retry. After a fix that didn't take, park that
  piece like a question and move on.
- **Nothing left = stop.** Every piece is done or parked. Then end with one report: what landed
  (PR url), what's parked (the question, where it lives), what wasn't verified.

## In a veri run or a vish session

The workflow's own rules still govern *how* each step is done; `afk` only removes the stops
between steps. A step the workflow says to stop at for the user (vish's taken-lane label, a
veri bail) is parked per that workflow's own procedure, and the run continues with whatever else
isn't blocked by it.

## What this does not change

Being away grants nothing. Irreversible, billable or outward-facing actions, merging, and work in
another repo wait exactly as the user's standing rules say — park them like a question, don't do
them and don't stop for them.
