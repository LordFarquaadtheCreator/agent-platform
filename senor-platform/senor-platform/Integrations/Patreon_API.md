# Patreon API — Source of Truth

Authoritative reference for Patreon API v2 endpoints used by Senor Platform.
Source: https://docs.patreon.com/ (verified 2026-05-21)

**Base:** `https://www.patreon.com/api/oauth2/v2`
**Format:** JSON:API spec — all data wrapped in `data` + `included`, fields/includes must be explicitly requested.
**Auth:** OAuth2 Bearer token. `Authorization: Bearer <access_token>`. Required `User-Agent` header or 403.
**Rate limits:** 100 req/2s per client, 100 req/min per token. 429 returns `retry_after_seconds`.

---

## OAuth

| Step | Endpoint | Method | Notes |
|---|---|---|---|
| Authorize | `https://www.patreon.com/oauth2/authorize` | GET | `response_type=code`, `client_id`, `redirect_uri`, `scope`, `state` |
| Token exchange | `https://www.patreon.com/api/oauth2/token` | POST | `Content-Type: application/x-www-form-urlencoded`. `grant_type=authorization_code` |
| Refresh | `https://www.patreon.com/api/oauth2/token` | POST | `grant_type=refresh_token` |

Token response: `{ access_token, refresh_token, expires_in, scope, token_type: "Bearer" }`.

### Scopes (v2)

| Scope | Grants |
|---|---|
| `identity` | Read user profile |
| `identity[email]` | Read user email |
| `identity.memberships` | Read user's memberships across all campaigns |
| `campaigns` | Read campaign data |
| `campaigns.members` | Read campaign members |
| `campaigns.members[email]` | Read member emails |
| `campaigns.members.address` | Read member addresses |
| `campaigns.posts` | Read campaign posts |
| `w:campaigns.webhook` | Full CRUD on webhooks created by this client |
| `campaigns.lives` | Read livestreams |
| `w:campaigns.lives` | Create/update livestreams |

**Scope behavior:** Reauthorizing appends scopes — never reduces. Always request full set.

---

## Resource Endpoints

All GET. Bracketed params (`fields[member]=...`) must be URL-encoded as `fields%5Bmember%5D=...`.

| Endpoint | Purpose | Scope | Top-level includes |
|---|---|---|---|
| `GET /identity` | Current user | `identity` | `memberships`, `campaign` |
| `GET /campaigns` | List user's campaigns | `campaigns` | `tiers`, `creator`, `benefits`, `goals` |
| `GET /campaigns/{id}` | Single campaign | `campaigns` | same as above |
| `GET /campaigns/{id}/members` | List campaign members | `campaigns.members` | `address`, `campaign`, `currently_entitled_tiers`, `user`, `pledge_history` |
| `GET /members/{id}` | Single member (UUID, not user_id) | `campaigns.members` | same as above |
| `GET /campaigns/{id}/posts` | List campaign posts | `campaigns.posts` | (none documented) |
| `GET /posts/{id}` | Single post | `campaigns.posts` | (none documented) |

### Live (early-access)

| Endpoint | Purpose | Scope |
|---|---|---|
| `POST /lives` | Create livestream | `w:campaigns.lives` |
| `GET /lives/{id}` | Get livestream | `campaigns.lives` |
| `PATCH /lives/{id}` | Update state | `w:campaigns.lives` |

---

## Webhook Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/webhooks` | GET | List webhooks created by this client |
| `/webhooks` | POST | Create webhook |
| `/webhooks/{id}` | PATCH | Update webhook |
| `/webhooks/{id}` | DELETE | Delete webhook |

Body: JSON:API document with `type: "webhook"`, `attributes: { triggers, uri, paused }`, `relationships: { campaign: { data: { type: campaign, id } } }`.

**Triggers (v2):** `members:create`, `members:update`, `members:delete`, `members:pledge:create`, `members:pledge:update`, `members:pledge:delete`, `posts:publish`, `posts:update`, `posts:delete`.

Webhook payload includes `X-Patreon-Signature` header — HMAC-MD5 hex digest of body with webhook secret.

---

## Pagination

Cursor-based via `meta.pagination.cursors.next`.

```
?page[count]=100&page[cursor]=<cursor>
```

Members endpoint returns 1000/page (500 if `pledge_history` included).

---

## Key Resource Fields

### Member
`patron_status` (`active_patron` | `declined_patron` | `former_patron` | `null`),
`currently_entitled_amount_cents`, `lifetime_support_cents` (deprecated — use `campaign_lifetime_support_cents`),
`last_charge_date`, `last_charge_status` (`Paid` | `Declined` | `Pending` | …),
`pledge_relationship_start`, `next_charge_date`, `will_pay_amount_cents`,
`is_free_trial`, `is_gifted`, `email`, `full_name`, `note`.

**Deprecated:** `is_follower` always `false`. Followers replaced by free-tier membership (members with no pledge / `patron_status: null`).

### Post v2
`title`, `content` (HTML), `is_paid`, `is_public`, `published_at`, `url`, `embed_data`, `embed_url`, `tiers` (entitled tier IDs).

### Campaign v2
`name`, `vanity`, `summary`, `creation_name`, `patron_count`, `is_monthly`, `is_charged_immediately`, `is_nsfw`, `pledge_url`, `url`, `discord_server_id`, `published_at`, etc.

### Tier
`amount_cents`, `title`, `description`, `patron_count`, `requires_shipping`, `published`, `discord_role_ids`, `user_limit`, `remaining`.

### User v2
`full_name`, `first_name`, `last_name`, `email` (only with `identity.email`), `image_url`, `thumb_url`, `url`, `about`, `is_creator`, `is_email_verified`, `social_connections`, `like_count`.

---

## What Patreon API v2 DOES NOT SUPPORT

Documented gaps — no public endpoints exist for:

- **Creating posts** — no `POST /posts`
- **Updating posts** — no `PATCH /posts/{id}`
- **Deleting posts** — no `DELETE /posts/{id}`
- **Direct messages / conversations** — no messages API
- **Notifications feed** — no notifications API
- **Followers as a distinct resource** — `is_follower` deprecated; query members with `patron_status == null` and `currently_entitled_amount_cents == 0` instead
- **Comments on posts** — no comments API
- **Campaign stats / analytics** — only `patron_count` on campaign
- **Tier CRUD** — read-only via include on campaign

Anything beyond GET in those areas must be done by the creator in the Patreon web UI. Webhook subscriptions (`posts:publish`, etc.) are the only programmatic post-event surface.

---

## Errors

| Code | Meaning |
|---|---|
| 400 | Bad request |
| 401 | Unauthorized (expired/invalid token, wrong scope) |
| 403 | Forbidden / missing User-Agent |
| 404 | Not found |
| 429 | Rate limited — honor `retry_after_seconds` |
| 5xx | Server error / maintenance |

Edge rate-limit: > 2000 4xx in 10 min → 30 min block.
