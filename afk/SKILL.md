---
name: afk
description: >-
  Drive the work forward unattended: keep going on every thread that doesn't need the user, park
  the ones that do with the question recorded, and when everything unblocked is done, spend the
  remaining time making the next session cheaper — stale docs, contradictions, test gaps, dead
  code. Use when the user says "afk", "I'm going afk", "keep going without me", "do what you can
  without me", "work on this while I'm out", "I'll be back in an hour", "drive it yourself",
  "sigue sin mí", "no me esperes", or otherwise hands over and leaves. Their absence is not
  authorization: irreversible actions still wait, and a decision that needed them gets parked
  rather than guessed. Merging is the one exception, and it is built in: saying "afk" is the
  standing instruction to merge whatever the run finishes in the project repo, through the `merge`
  skill, unless the user says "don't merge" on the way out. Other repos are out of scope entirely:
  the run never starts work in one, and never merges there.
---

# AFK — drive what can be driven, park what can't

The user is gone and the clock is running. The value here is that they come back to **finished
work plus a short list of decisions**, not to a session that stalled on question one — and not to
a pile of changes made in their name that they never agreed to.

## The line that does not move

**Being away is the opposite of authorization.** Nobody is watching, so the gates matter more, not
less. Still requiring an explicit yes: deploying, anything billable, force-pushing, deleting data,
sending anything outward, and any action whose undo is "restore from a backup and apologise". If
the reasoning starts with *they'd probably want* — that is the feeling of about to do something
that needs asking. None of these has an advance form: "deploy it when green" or "delete the old
bucket while I'm out" is a request to park with the question recorded, not a request to do it.

Pushing branches and opening PRs is not in that set. Work that stays local is work they cannot see
when they return, so **everything lands as a pushed branch with a PR** — merged if it is finished,
draft if it is parked.

**And the run stays inside the project repo.** An unattended agent that wanders into a second repo
is making a scope decision nobody was there to approve. A fix that belongs elsewhere is parked as
a line in the brief — repo, file, what the change would be — not gone and done. If they asked
before leaving for a PR in another repo, it goes to branch → push → PR and stops there; the merge
permission below does not reach it.

## Merging is included

**Saying "afk" is the merge instruction for the run.** It is not inferred from their absence; it is
what this skill means, and what the `merge` skill's "only when the user says to" is satisfied by.
They do not have to add "merge it when green" — a finished thread is merged, not left as a draft
for them to click through when they return. The whole point of the run is that they come back to
work that has *landed*.

It covers **PRs in the project repo only.** A PR in any other repo still needs them to say so for
that PR — green, trivial and finished does not change it.

What "finished" means does not loosen because nobody is watching:

- **Verified, and CI green by the `merge` skill's gate** — the rollup, `total > 0`, nothing
  pending, nothing failed. Not `gh pr checks` exiting 0, not a tick in the UI, not an empty rollup
  read as "no CI". A PR whose checks never start does not merge; it parks with that noted.
- **No open question in the PR body.** A parked PR is never merged, whatever its CI says — it
  carries a decision they have not made, and merging it makes the decision for them.
- **Not on the [Not while unattended](#not-while-unattended) list.** The permission covers what
  the run may finish, not what it should never have started.

**The permission covers the merge, not what the merge skill hands back.** A rebase conflict is
still theirs to resolve; a `BLOCKED` merge state is still a gate not to walk around; a pinned-lease
rejection still means stop and look. The skill's own limits apply unchanged — "afk" replaces the
"merge it" at step 0, nothing after it.

**Narrowing is theirs, by saying so.** "Afk, but don't merge", "afk, leave #12 for me to look at",
"no mergees nada" — an explicit hold on the way out is honoured as written, and only for what it
names. A hold given last week about a different PR does not carry.

**Every merge is a line in the brief with its merge sha.** They should not have to diff `main`
against their memory to find out what landed while they were out. Then the cleanup the merge skill
does anyway: remote branch deleted, primary clone pulled, worktree removed.

## Working the threads

Take stock first — observed state, not recollection: `git status`, open PRs and their CI, the task
list, what the last session left half-done. Then, per thread:

| | |
|---|---|
| **Nothing blocking it** | Drive it to done, verified, pushed, PR opened, merged |
| **Needs a decision only they can make** | Park it. Do not guess |
| **Blocked on something external** — CI, a deploy, a third party | Park it, note what it waits on |

**One thread, one branch, one PR.** The temptation while unattended is to keep piling into a
single branch because nobody is there to object. Don't: a five-subject diff is unreviewable, and
review is the whole point of coming back. If two threads touch the same files, do the one that
unblocks the other and park the second with that noted.

**Move on rather than escalating.** When a thread parks, the next thread starts. An AFK run that
returns three finished pieces and two clear questions is a good run; one that returns five
half-finished pieces because it kept circling the hard one is not.

## Delegate the reading, keep the deciding

**An unattended run ends when the context does, not when the work does.** Nobody is there to
`/clear` and restart you, so every file dump, search sweep, build log and test transcript the main
thread absorbs directly is time taken off the end of the run. This is the single biggest lever on
how much gets finished, which is why it belongs here rather than as an afterthought.

So push the raw material into subagents and keep only what you concluded — call the Skill tool with
`"delegate"` for how to write a self-contained prompt with an explicit return contract, and for
worktree isolation when threads write concurrently. Good candidates: exploring an unfamiliar area,
searching for every call site, reading ten files to answer one question, running a long suite.
Anything whose value to you is a conclusion rather than the material itself.

Two things stay in the main thread. **Whether a thread is driven or parked** is the judgement this
skill is about, and it needs the whole picture rather than one agent's slice. And **the return
brief**, which is your account of the run — not something to assemble from reports you did not
check. A subagent's answer is a claim; verify the load-bearing ones before they reach the brief.

## Parking properly

A parked thread is not an abandoned one. It gets, in this order:

1. **Committed and pushed**, even mid-work — a WIP commit whose message says what is half-done and
   what it breaks. Never a dirty tree, never a stash: the stash stack is shared across worktrees
   and another session can pop it.
2. **A draft PR whose body carries the question** — what the choice is, the options, what each
   costs, and a recommendation. Put it in the PR rather than in chat: chat scrollback dies with
   the session, the PR is still there tomorrow.
3. **One line in the return brief**, so they don't have to open five PRs to find the five
   questions.

The recommendation matters. "I need your input on the cache strategy" is a question they have to
reconstruct the context for; "write-through or write-behind — recommend write-through, because the
read path already assumes freshness" is one they can answer in a word.

## When everything unblocked is done

Don't stop, and don't invent features. Spend the time on the work that never gets prioritised
because it is nobody's ticket — and take it **in this order**, because it is ranked by what it
costs to leave undone:

1. **Things that actively mislead.** A doc that contradicts the code, two files that disagree, a
   count in prose that no longer matches the thing it counts, a command in the README that fails.
   These are worse than absent: the next session trusts them and goes the wrong way. When two
   sources disagree, check which one the code agrees with, fix the other, and record which won and
   why — a contradiction silently resolved is one that comes back.
2. **Things that make every future session cheaper.** This is the highest-leverage category and
   the least obvious. A `CLAUDE.md` gap that makes every session re-derive the same fact. A ten-
   command dance that should be one script. A test command that dumps thousands of lines when it
   passes, flooding context for no information. A suite so slow nobody runs it before pushing.
   Fixtures duplicated across ten test files. Each of these is a tax paid on every future run.
3. **Test gaps where the failure would be expensive** — the untested failure path, the gap the
   build does not check, the assertion nobody has watched fail. Add the test, break the thing on
   purpose to confirm the test fires, put it back. A test added while unattended that has never
   been seen to fail is decoration.
4. **Dead code and stale scaffolding** — last, because it is the riskiest and pays least. Removal
   needs an observed fact: the search that shows nothing references it, quoted. Not "this looks
   unused". If the evidence isn't conclusive, park it as a PR that proposes the deletion instead
   of doing it.

## Not while unattended

Each of these produces a diff too large to review against a decision nobody was there to weigh:

- Dependency upgrades, framework bumps, toolchain swaps
- Repo-wide reformatting or lint-rule changes
- Renames across the codebase
- Architecture changes, or refactors that alter behaviour
- Anything that starts "while I was in there I also"
- Anything in a repo other than the project one — including a change they'd obviously want

A behaviour-preserving cleanup inside one module is fine. The test is whether a reviewer can check
it without reconstructing your reasoning.

## Budget

An unattended run is where budget goes quietly. When it starts running low, stop opening threads
and land what is open — call the Skill tool with `"low-fuel"` for the landing order. Coming back to
three merged PRs and a note beats coming back to six branches that never got pushed.

## The return brief

Short, and the first thing they see. This is what the whole run was for:

```
**Merged** — <what, PR url, merge sha>                          (verified; say if not)
**Landed unmerged** — <what, PR url> — why: <the reason it did not merge>
**Parked** — <thread> — needs: <the question, with a recommendation, PR url>
**Left alone** — <what you didn't touch and why>
```

Honest about gaps: what failed, what was skipped, what could not be verified. A brief that reads
as clean when a check was skipped is worse than the skipped check — they will make the next
decision believing it passed.
