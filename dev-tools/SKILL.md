---
name: dev-tools
description: >-
  The once-per-repo setup jobs, loaded only when named: `/dev-tools guardrails`, `/dev-tools
  house-style`, `/dev-tools aws-sso`. No argument lists them.
disable-model-invocation: true
---

# Dev-tools — the once-only jobs, off the always-loaded list

Each job below happens once per repo or once per machine. A skill's body is already lazy — it is
not in the prompt until it is called — but its `description` is resident in every session of every
project, and a description is mostly trigger phrases. These three carried 362 words of trigger
surface between them for 2 invocations total. So they are reached by argument instead: this file's
30-word description is all that stays loaded, and the procedure is read only when you name it.

| Argument | The job | Read and follow |
|---|---|---|
| `guardrails` | Install or update the git hooks that park the primary clone on `main` and push work into worktrees | `guardrails/SKILL.md` |
| `house-style` | Bring a repo up to the engineering conventions and write its own `CLAUDE.md` | `house-style/SKILL.md` |
| `aws-sso` | Migrate `~/.aws/config` onto `sso-session` blocks, then explain where session duration lives | `aws-sso/SKILL.md` |

Those three paths are symlinks to the real skill directories, which is what keeps this dispatcher
free of absolute paths. A relative path *inside* the file you read resolves against the symlink you
read it through, not against this directory: in `guardrails/SKILL.md`, `references/evidence.md`
means `guardrails/references/evidence.md`. Follow such a path exactly as written — prefix it with
the argument's directory, never rewrite it and never go looking for it next to this file.

Verified: only `<skills root>/<name>/SKILL.md` is registered as a skill, so the `SKILL.md` behind
each symlink here is read as a file and never loaded as a skill of its own. That is what keeps
their descriptions out of the always-resident prompt, which is the whole point of this dispatcher.

**No argument, or one not in the table** → print the table and stop. Never pick a job for the user:
all three write to their machine, and two of them install hooks.

**Read the whole file before acting on any of it.** Each fails closed in its own way, and the gates
live in the prose, not only in the commands.

## Why they are not linked

Each carries an `.on-demand` marker, so `/sync-config` deliberately leaves it unlinked — that is
the intended state, not an oversight. Reaching them through this skill replaces the older
link-it-then-remove-it dance: nothing to install by hand, nothing to remember to undo.

Adding a fourth: drop the marker in its directory, symlink it here, add the row. Keep the
description out of it — the saving *is* the trigger phrases not being loaded.
