---
name: afk
description: >-
  Drive the work forward unattended: keep going on every thread that doesn't need the user, park the
  ones that do with the question recorded, and when everything unblocked is done, spend the
  remaining time making the next session cheaper — stale docs, contradictions, test gaps, dead code.
  Use when the user says "afk", "I'm going afk", "keep going without me", "do what you can without
  me", "work on this while I'm out", "I'll be back in an hour", "drive it yourself", "sigue sin mí",
  "no me esperes", or otherwise hands over and leaves. Their absence is not authorization:
  irreversible actions still wait, and a decision that needed them gets parked rather than guessed.
  Merging is the one exception and it is built in: saying "afk" is the standing instruction to merge
  whatever the run finishes in the project repo, through the `merge` skill, unless they say "don't
  merge" on the way out. Other repos are out of scope entirely — the run never starts work in one,
  and never merges there.
---

# AFK — drive what can be driven, park what can't

They come back to **finished work plus a short list of decisions**, not to a session that stalled on
question one, and not to changes made in their name they never agreed to.

## The line that does not move

**Being away is the opposite of authorization.** Still needing an explicit yes: deploying, anything
billable, force-pushing, deleting data, sending anything outward, anything whose undo is "restore
from backup and apologise". Reasoning that starts *they'd probably want* is the feeling of about to
do something that needs asking. None of these has an advance form — "deploy it when green" or
"delete the old bucket while I'm out" is a request to park with the question recorded.

**Billable includes the config-shaped kind.** A workflow file, a cron schedule, an extra matrix leg,
a `runs-on:` that isn't `ubuntu-latest` — these bill on every run from then on and announce nothing.
Nothing that creates or widens a recurring cost gets written unattended; it goes in the brief as a
proposal with the price on it.

Pushing branches and opening PRs is *not* in that set: work that stays local is work they cannot see
when they return, so **everything lands as a pushed branch with a PR** — merged if finished, draft if
parked.

**The run stays inside the project repo.** A fix that belongs elsewhere is parked as a line in the
brief (repo, file, what the change would be), not gone and done. If they asked before leaving for a
PR in another repo, it stops at branch → push → PR; the merge permission below does not reach it.

## Merging is included

**Saying "afk" is the merge instruction for the run** — not inferred from absence, and what the
`merge` skill's "only when the user says to" is satisfied by. **Project repo only**; a PR anywhere
else still needs them to say so for that PR.

"Finished" does not loosen because nobody is watching:

- **CI green by the `merge` skill's gate** — rollup, `total > 0`, nothing pending, nothing failed.
  Not `gh pr checks` exiting 0, not a tick, not an empty rollup read as "no CI". A PR whose checks
  never start parks with that noted.
- **No open question in the PR body.** A parked PR never merges whatever its CI says — merging it
  makes the decision for them.
- **Not on the Not-while-unattended list** below. The permission covers what the run may finish, not
  what it should never have started.

**It covers the merge, not what the merge skill hands back.** A rebase conflict is still theirs; a
`BLOCKED` state is still a gate; a pinned-lease rejection still means stop. "afk" replaces the
"merge it" at step 0, nothing after it.

**Narrowing is theirs, by saying so** — "afk, but don't merge", "afk, leave #12 for me", "no mergees
nada" — honoured as written, only for what it names, and a hold from last week does not carry.

**Every merge is a line in the brief with its merge sha**, then the cleanup `merge` does anyway:
remote branch deleted, primary pulled, worktree removed.

## Working the threads

Take stock from observed state first: `git status`, open PRs and their CI, the task list, what the
last session left half-done. Then per thread:

| | |
|---|---|
| **Nothing blocking it** | Drive to done: verified, pushed, PR, merged |
| **Needs a decision only they can make** | Park it. Do not guess |
| **Blocked externally** — CI, a deploy, a third party | Park it, note what it waits on |

**One thread, one branch, one PR.** A five-subject diff is unreviewable, and review is the point of
coming back. Two threads touching the same files → do the one that unblocks the other, park the
second with that noted.

**Move on rather than escalating.** Three finished pieces and two clear questions is a good run;
five half-finished pieces because it kept circling the hard one is not.

## Delegate the reading, keep the deciding

**The run ends when the context does, not when the work does** — nobody is there to `/clear` you. So
every file dump, search sweep, build log and test transcript goes into a subagent; call the Skill
tool with `"delegate"` for the prompt contract and worktree isolation. Good candidates: exploring an
unfamiliar area, finding every call site, reading ten files for one answer, running a long suite.

Two things stay in the main thread: **whether a thread is driven or parked**, which needs the whole
picture, and **the return brief**, which is your account of the run. A subagent's answer is a claim
— verify the load-bearing ones before they reach the brief.

## Parking properly

1. **Committed and pushed**, even mid-work — a WIP commit saying what is half-done and what it
   breaks. Never a dirty tree, never a stash (the stack is shared across worktrees).
2. **A draft PR whose body carries the question** — the choice, the options, what each costs, and a
   recommendation. In the PR, not in chat: scrollback dies with the session.
3. **One line in the return brief.**

Not "I need your input on the cache strategy" but "write-through or write-behind — recommend
write-through, because the read path already assumes freshness". One they can answer in a word.

## When everything unblocked is done

Don't stop, don't invent features. Ranked by what it costs to leave undone:

1. **Things that actively mislead** — a doc contradicting the code, two files that disagree, a count
   in prose that no longer matches, a README command that fails. Worse than absent: the next session
   trusts them. When two sources disagree, check which the code agrees with, fix the other, record
   which won and why.
2. **Things that make every future session cheaper** — highest leverage, least obvious. A `CLAUDE.md`
   gap that makes every session re-derive the same fact. A ten-command dance that should be a script.
   A test command that dumps thousands of lines when it passes. A suite too slow to run before
   pushing. Fixtures duplicated across ten test files.
3. **Test gaps where the failure would be expensive** — the untested failure path, the gap the build
   doesn't check. Add the test, break the thing on purpose to confirm it fires, put it back. A test
   never seen to fail is decoration.
4. **Dead code and stale scaffolding** — last: riskiest, pays least. Removal needs the search that
   shows nothing references it, quoted. Inconclusive → a PR proposing the deletion, not the deletion.

## Not while unattended

Each produces a diff too large to review against a decision nobody weighed:

- Dependency upgrades, framework bumps, toolchain swaps
- Repo-wide reformatting or lint-rule changes; renames across the codebase
- Architecture changes, or refactors that alter behaviour
- Anything starting "while I was in there I also"
- Anything in a repo other than the project one, including a change they'd obviously want
- Anything that starts something billing on a schedule

A behaviour-preserving cleanup inside one module is fine. Test: can a reviewer check it without
reconstructing your reasoning?

## Budget

Running low → stop opening threads and land what is open; call the Skill tool with `"low-fuel"` for
the order. Three merged PRs and a note beats six branches that never got pushed.

## The return brief

Short, first thing they see:

```
**Merged** — <what, PR url, merge sha>                          (verified; say if not)
**Landed unmerged** — <what, PR url> — why: <reason it did not merge>
**Parked** — <thread> — needs: <the question, with a recommendation, PR url>
**Left alone** — <what you didn't touch and why>
```

Honest about gaps: what failed, what was skipped, what could not be verified. A brief that reads
clean over a skipped check is worse than the skipped check.
