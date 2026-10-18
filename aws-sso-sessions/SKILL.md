---
name: aws-sso-sessions
description: >-
  Migrate an AWS CLI v2 config from the legacy per-profile SSO form (`sso_start_url` inside each
  profile) to `sso-session` blocks, then explain why a login expires when it does. Use when the
  user says "migrate my aws config", "aws sso session", "multiple aws sso logins", "log into two
  aws accounts", "why does my aws sso keep expiring", "keep my aws session alive", "sso-session" —
  or when they fight repeated AWS SSO re-authentication, want two accounts or portals signed in at
  once, or ask where the session length is set. Backs up the config, verifies the rewrite without
  opening a browser, and never runs `aws sso login` itself.
---

# AWS SSO sessions — migrate the config, then explain the clock

Migrate for what legacy cannot do: **several SSO sessions live at once** (cache keyed per session)
and **refresh tokens** (a session outlives its first hour).

AWS CLI v2. Export `AWS_PAGER=""` before any `aws` call, or the pager opens and never returns.

**Linked on demand** — once done, offer `rm ~/.claude/skills/aws-sso-sessions`.

## Hard rules

- **Never write `~/.aws/config` without a verified backup on disk.** Verified = compared, not `cp`
  exited 0.
- **Never delete anything in `~/.aws/sso/cache/`.** Orphans expire on their own; if asked, list them
  and let the user delete.
- **Never run `aws sso login`.** Needs a browser and the user present; unattended it burns a
  device-authorization code.
- **Never print an `accessToken`, `refreshToken` or `clientSecret`.** From a cache file read only
  `startUrl`, `expiresAt`, whether a `refreshToken` key exists, and `registrationExpiresAt`.
  `scripts/inspect_sso_cache.py` prints exactly those — prefer it over `cat`.

## 1. Classify

| Bucket | Recognised by | Action |
|---|---|---|
| Legacy | `sso_start_url` inside `[profile …]` | Migrate |
| Already migrated | `sso_session = NAME` | Leave alone |
| Non-SSO | static keys, `credential_process`, `role_arn`, … | Never touch |

Report the counts first. Capture the profile list now; step 5 diffs against it.

```bash
export AWS_PAGER=""
aws configure list-profiles | sort > /tmp/profiles-before.txt
```

## 2. Back up, and prove it

```bash
cp -p ~/.aws/config ~/.aws/config.bak.$(date +%Y%m%d-%H%M%S)
cmp ~/.aws/config ~/.aws/config.bak.<stamp> && echo "backup verified"
```

`cmp` is silent on success — that silence is the evidence. Write nothing until it prints; show the
path.

## 3. Group, then let the user name the groups

Group legacy profiles by `(sso_start_url, sso_region)`. **Each distinct pair becomes exactly one
`[sso-session NAME]`** — a login authenticates against that pair.

**Ask the user to name each one; don't invent names.** The name is the cache key and what they type
after `--sso-session`.

- **Expect one extra login:** the cache key moves from `sha1(sso_start_url)` to `sha1(session_name)`,
  so the current token is orphaned and ages out.
- **A second session name on a start URL that already has one buys nothing** — same identity, two
  logins to keep alive. Say so rather than doing it.
- **Strip a trailing `/#`** from the start URL. It is part of the legacy cache key, so two profiles
  differing only by it cost two logins for one portal.

## 4. Rewrite

Session blocks first, then profiles. **Preserve each profile's values exactly** — `sso_account_id`,
`sso_role_name`, `region`, `output`, a *missing* `output` included — a real difference, not an
oversight.

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

`sso_registration_scopes = sso:account:access` on **every** session block — without it the token
carries no refresh token and the migration buys concurrency only.

## 5. Verify without a browser

All three run offline. Show the output.

```bash
aws configure list-profiles | sort | diff /tmp/profiles-before.txt -   # expect no output
aws configure list --profile <one-migrated-profile>
diff ~/.aws/config.bak.<stamp> ~/.aws/config
```

The middle one **is supposed to fail**, with `Error loading SSO Token: Token for <session-name> does
not exist` — proof the profile resolved to its session. A parse failure names the profile or the
file, never the session. Read the message.

## 6. Hand the login back

```bash
aws sso login --sso-session <name>
```

They run it, not you.

## 7. Session duration — only if they ask

**Read [`references/session-duration.md`](references/session-duration.md) before saying anything
about durations** — several near-miss settings look like the answer.

## After migrating: what still takes `--profile`

**`sso_session` is only for `aws sso login`.** Every downstream consumer — CDK, the SDKs, Terraform,
`aws` itself — still selects a profile with `--profile` or `AWS_PROFILE`. Say so when it lands.

## Adding a session later

| Command | Writes |
|---|---|
| `aws configure sso-session` | Just the `[sso-session …]` block |
| `aws configure sso` | Session block, browser login, and a profile, in one walk |

Use the first when profiles already exist and need a session to point at.

## Concurrency, and the real ceiling

One token per session name, so **sessions do not compete** — several stay live. The ceiling is the
browser, per *identity*: two portals coexist, but one portal as two users needs a separate browser
profile, or `aws sso login --no-browser`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Error loading SSO Token: Token for X does not exist` | Migrated, not yet logged in. Expected until the first `aws sso login --sso-session X` |
| Re-prompted every ~8 hours | Either `sso_registration_scopes` is missing from the session block, so no refresh token was issued, or the instance's **user interactive session** duration is still the 8h default |
| Two logins for one apparent portal | Two start URLs differing only by a trailing `/#`, each with its own legacy cache file. Migrate both onto one session |
| Worked yesterday, dead this morning, no error until the first command | Refresh is lazy — on the next AWS call, not in the background. Normal inside the session duration |
