# How long an AWS SSO login lasts, and where that is set

Read this before answering anything about durations. Nearly every value on the way to the right
answer looks like the answer, and three of them are different settings entirely.

## What each token actually is

A cache file in `~/.aws/sso/cache/<sha1>.json` holds two clocks that get confused with each other:

| Field | What it is | Typical |
|---|---|---|
| `expiresAt` | The **access token** TTL | 1h with a refresh token; otherwise the portal session duration |
| `registrationExpiresAt` | The **device registration** — this client's right to ask for tokens at all | ~90 days |

**`registrationExpiresAt` is not the session duration.** It is the single most common
misreading — a 90-day number sitting in the file the user is already looking at, which is why they
reach for it. Say what it is rather than only what it isn't.

## Reading the duration off a token, when nothing else will tell you

- **With a refresh token**, the access token TTL is exactly **1 hour** and renews silently. The
  number tells you nothing about the session.
- **Without one**, the access token TTL **is** the portal session duration.

So an 8-hour `expiresAt` on a refresh-less token is a reliable read of that instance's session
duration. This inference is worth knowing because no API will hand you the number.

Legacy per-profile SSO tokens never carry a `refreshToken`. `sso-session` tokens issued with
`sso_registration_scopes = sso:account:access` do — that is the real reason to migrate.

## No API returns the session duration

This was established by enumerating all ~90 `aws sso-admin` operations, so it does not need
re-deriving:

- `describe-instance` has no duration field.
- `get-application-session-configuration` / `put-application-session-configuration` govern
  **customer-managed applications**, not the portal.

It is console-only:

> IAM Identity Center → Settings → Authentication → Session settings

Don't send the user hunting for a CLI flag — there isn't one, and looking is a long dead end.

## Three values live in that panel, and only one is the answer

| Setting | Governs |
|---|---|
| **User interactive sessions** | `aws sso login` and browser sign-in. **This is the one.** Default 8 hours |
| User background sessions | Non-interactive flows |
| Kiro sessions | The Kiro IDE only |

Naming the right one saves a real round-trip, because all three are visible at once and two of them
are plausible.

## It is a ceiling, not an idle timer

The duration is measured from authentication. Using AWS all day does **not** slide it forward — an
8-hour session that began at 09:00 ends at 17:00 whether it was busy or idle.

Refresh is **lazy**: it happens on the next AWS call, not from a daemon. Closing the laptop and
coming back tomorrow is fine, as long as tomorrow is still inside the session duration.

## The near-miss setting

`aws sso-admin describe-permission-set` returns `SessionDuration` (`PT1H`–`PT12H`). That is **how
long one set of role credentials lasts**, not how long the login lasts. Two different clocks; don't
conflate them, and don't offer it as the fix for "my SSO keeps expiring".

## Before promising the user they can change it

Every `sso-admin` call requires the **Identity Center management account**. From a member account
they return `AccessDeniedException`, which reads like a permissions bug and isn't one.

```bash
export AWS_PAGER=""
aws sso-admin list-instances --query 'Instances[].OwnerAccountId' --output text
aws sts get-caller-identity --query Account --output text
```

If those differ, the user is not in the management account. Say that before telling them where the
setting is, so they don't go looking for a panel they cannot reach.
