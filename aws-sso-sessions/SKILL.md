---
name: aws-sso-sessions
description: >-
  Migrate an AWS CLI v2 config from the legacy per-profile SSO form (`sso_start_url` inside each
  profile) to `sso-session` blocks, then reason about why a login expires when it does. Use when the
  user says "migrate my aws config", "aws sso session", "multiple aws sso logins", "log into two aws
  accounts", "why does my aws sso keep expiring", "keep my aws session alive", "sso-session", "migra
  mi config de aws" — and when they are fighting repeated AWS SSO re-authentication, want two
  accounts or portals signed in at once, or ask where the session length is set. Backs up the config
  and verifies the rewrite without opening a browser, and never runs `aws sso login` itself.
---

# AWS SSO sessions — migrate the config, then explain the clock

Two things the legacy form cannot do, and the whole reason to migrate: **several SSO sessions logged
in at once** (the token cache is keyed per session, so two portals coexist instead of overwriting
each other) and **refresh tokens** (a session survives past its first hour instead of dying with the
access token).

AWS CLI v2 throughout. Export `AWS_PAGER=""` before any `aws` call, or the pager opens and the command
never returns.

**Linked on demand.** The migration happens once per machine, so when the job is done offer to remove
the link: `rm ~/.claude/skills/aws-sso-sessions`.

## Hard rules

Every one is a mistake that costs the user access or secrets, and none is recoverable by apologising.

- **Never write `~/.aws/config` without a verified backup already on disk.** Verified means you
  compared it, not that `cp` exited 0.
- **Never delete anything in `~/.aws/sso/cache/`.** Orphaned tokens are harmless and expire on their
  own. If asked, list what is orphaned and let the user delete it.
- **Never run `aws sso login`.** It needs a browser and the user present; unattended it just burns a
  device-authorization code.
- **Never print an `accessToken`, `refreshToken` or `clientSecret`.** From a cache file read only
  `startUrl`, `expiresAt`, whether a `refreshToken` key exists, and `registrationExpiresAt`.
  `scripts/inspect_sso_cache.py` prints exactly those — prefer it over `cat`, so the rule is enforced
  by the tool rather than by remembering.
- **Verify by reading output.** Skipped a check → say which and why.

## 1. Classify

| Bucket | Recognised by | Action |
|---|---|---|
| Legacy | `sso_start_url` inside `[profile …]` | Migrate |
| Already migrated | `sso_session = NAME` | Leave alone |
| Non-SSO | static keys, `credential_process`, `role_arn`, … | Never touch |

Report the counts before proposing anything. Capture the profile list now; step 5 compares against it.

```bash
export AWS_PAGER=""
aws configure list-profiles | sort > /tmp/profiles-before.txt
```

## 2. Back up, and prove it

```bash
cp -p ~/.aws/config ~/.aws/config.bak.$(date +%Y%m%d-%H%M%S)
cmp ~/.aws/config ~/.aws/config.bak.<stamp> && echo "backup verified"
```

Show the path. `cmp` is silent on success — that silence is the evidence. Nothing is written until
that prints.

## 3. Group, then let the user name the groups

Group legacy profiles by the pair `(sso_start_url, sso_region)`. **Each distinct pair becomes exactly
one `[sso-session NAME]`** — that pair is what a login authenticates against, so two profiles sharing
it share a session by definition.

**Ask the user to name each one. Don't invent names.** The name is the token cache key and what they
type after `--sso-session` for as long as the config lives.

- **Migrating invalidates the current token, so expect one extra login.** The cache key changes from
  `sha1(sso_start_url)` to `sha1(session_name)`; the old file just ages out.
- **A second session name on a start URL that already has one buys nothing** — same identity, same
  accounts, two logins to keep alive. Say so rather than doing it.

Strip a trailing `/#` from the start URL here. In the legacy form that fragment is part of the cache
key, so two profiles differing only by it demand two logins for one portal; once the key is the
session name it is harmless, which is why this is the moment to drop it.

## 4. Rewrite

Session blocks first, then profiles. **Preserve each profile's own values exactly** —
`sso_account_id`, `sso_role_name`, `region`, `output` — including a *missing* `output`, which is a
real difference, not an oversight to tidy.

```ini
[sso-session mysession]
sso_start_url = https://d-xxxxxxxxxx.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile myprofile]
sso_session = mysession
sso_account_id = 111122223333
sso_role_name = AdministratorAccess
region = us-east-1
output = json
```

`sso_registration_scopes = sso:account:access` goes on **every** session block: it is what makes the
issued token carry a refresh token, which is the payoff. Without it the migration buys concurrent
sessions and nothing else.

## 5. Verify without a browser

All three run offline. Show the output rather than summarising.

```bash
aws configure list-profiles | sort | diff /tmp/profiles-before.txt -   # expect no output
aws configure list --profile <one-migrated-profile>
diff ~/.aws/config.bak.<stamp> ~/.aws/config
```

The middle one **is supposed to fail**, with `Error loading SSO Token: Token for <session-name> does
not exist`. That error proves the profile resolved to its session and the CLI went looking for that
session's token. A config that failed to parse fails differently — it complains about the profile or
the file and never names the session. Read the message.

## 6. Hand the login back

```bash
aws sso login --sso-session <name>
```

They run it, not you.

## 7. Then, only if they ask

Offer to explain session duration — how long a login lasts, where it is set, why. Separate question,
answered in [`references/session-duration.md`](references/session-duration.md). **Read that file
before saying anything about durations**; the ground is full of near-miss settings that look like the
answer.

## After migrating: what still takes `--profile`

**`sso_session` is only for `aws sso login`.** Every downstream consumer — CDK, the SDKs, Terraform,
`aws` itself — still selects a profile with `--profile` or `AWS_PROFILE`. Say this explicitly when the
migration lands: reaching for `--sso-session` on an ordinary command is the first thing people get
wrong afterwards.

## Adding a session later

| Command | Writes |
|---|---|
| `aws configure sso-session` | Just the `[sso-session …]` block |
| `aws configure sso` | Session block, browser login, and a profile, in one walk |

The first is the one to reach for when the config already has profiles needing a session to point at.

## Concurrency, and the real ceiling

One token per session name, so **sessions do not compete** — several stay live. The constraint is the
browser, and it is about *identities*: two different portals sign in side by side, but the same portal
as two different users needs a separate browser profile, or `aws sso login --no-browser`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Error loading SSO Token: Token for X does not exist` | Migrated, not yet logged in. Expected until the first `aws sso login --sso-session X` |
| Re-prompted every ~8 hours | Either `sso_registration_scopes` is missing from the session block, so no refresh token was issued, or the instance's **user interactive session** duration is still the 8h default |
| Two logins for one apparent portal | Two start URLs differing only by a trailing `/#`, each with its own legacy cache file. Fixed by migrating both onto one session |
| Worked yesterday, dead this morning, no error until the first command | Refresh is lazy — on the next AWS call, not in the background. Normal inside the session duration |
