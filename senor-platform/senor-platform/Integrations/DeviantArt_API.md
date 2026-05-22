# DeviantArt API — Source of Truth

Authoritative reference for DeviantArt API v1 endpoints used by Senor Platform.
Source: https://www.deviantart.com/developers/ → https://deviantart.readme.io/reference (verified 2026-05-21)

**Base:** `https://www.deviantart.com/api/v1/oauth2`
**Auth:** OAuth2 Bearer. `Authorization: Bearer <access_token>`.
**Version pinning:** Send `dA-minor-version: 20240701` header (or as query param).
**Body format:** Most POSTs use `application/x-www-form-urlencoded`. File uploads use `multipart/form-data`.

---

## OAuth

| Step | Endpoint |
|---|---|
| Authorize | `GET https://www.deviantart.com/oauth2/authorize` (params: `response_type=code`, `client_id`, `redirect_uri`, `scope`, `state`) |
| Token exchange | `POST https://www.deviantart.com/oauth2/token` (`grant_type=authorization_code`) |
| Refresh | `POST https://www.deviantart.com/oauth2/token` (`grant_type=refresh_token`) |
| Revoke | `POST https://www.deviantart.com/oauth2/revoke` |
| Test token | `GET /placebo` |

### Scopes (only what we use)

| Scope | Grants |
|---|---|
| `browse` | Browse public content |
| `user` | Read user profile basics |
| `user.manage` | Update profile/avatar |
| `gallery` | Read user gallery |
| `collection` | Read user favorites |
| `stash` | Sta.sh access |
| `publish` | Publish from Sta.sh |
| `feed` | Read messages/feed |
| `comment.post` | Post comments |
| `message` | Read/delete messages |

---

## Identity / Account

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/user/whoami` | GET | **Current authenticated user — preferred for identity** | `user` |
| `/user/profile/{username}` | GET | Public profile of any user | `user` |
| `/user/profile` | POST | Update own profile | `user.manage` |
| `/user/profile/update/avatar` | POST | Update avatar (multipart) | `user.manage` |
| `/user/tiers` | GET | User's Patreon-like tier list | `user` |
| `/user/whois` | POST | Bulk lookup users by usernames | `user` |

`/user/whoami` returns: `userid`, `username`, `usericon`, `type`.
`/user/profile/{username}` returns: `user` block, `is_watching`, `profile_url`, `user_is_artist`, `artist_level`, `artist_specialty`, `real_name`, `tagline`, `countryid`, `country`, `website`, `bio`, `cover_photo`, `last_status`, `stats: { user_deviations, user_favourites, user_comments, profile_pageviews, profile_comments }`.

---

## Watchers / Followers

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/user/watchers/{username}` | GET | List user's watchers (followers) | `browse` |
| `/user/friends/{username}` | GET | List users being watched | `user` |
| `/user/friends/watching/{username}` | GET | Boolean: am I watching this user? | `user` |
| `/user/friends/watch/{username}` | POST | Watch (follow) a user | `user.manage` |
| `/user/friends/unwatch/{username}` | GET | Unwatch | `user.manage` |
| `/user/friends/search` | GET | Search through watched users | `user` |

Pagination: `offset`, `limit` (max 50). Returns `{ results: [...], has_more, next_offset }`.

---

## Gallery (own deviations)

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/gallery/all` | GET | All deviations across all folders | `browse` |
| `/gallery/folders` | GET | List gallery folders | `browse` |
| `/gallery/{folderid}` | GET | Folder contents | `browse` |
| `/gallery/folders/create` | POST | Create folder | `gallery` |
| `/gallery/folders/remove/{folderid}` | POST | Delete folder | `gallery` |
| `/gallery/folders/update` | POST | Update folder details | `gallery` |
| `/gallery/folders/copy_deviations` | POST | Copy deviations to folder | `gallery` |
| `/gallery/folders/move_deviations` | POST | Move deviations to folder | `gallery` |
| `/gallery/folders/remove_deviations` | POST | Remove deviations from folder | `gallery` |
| `/gallery/folders/update_deviation_order` | POST | Reorder deviations within folder | `gallery` |
| `/gallery/folders/update_order` | POST | Reorder folders | `gallery` |

Params: `username` (optional, defaults to self), `offset`, `limit` (max 24), `mature_content`.

---

## Deviations (posts)

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/deviation/{deviationid}` | GET | Single deviation | `browse` |
| `/deviation/content` | GET | HTML/text body (`?deviationid=…`) | `browse` |
| `/deviation/metadata` | GET | Tags, description, license (`?deviationids[]=…`, batch up to 50) | `browse` |
| `/deviation/download/{deviationid}` | GET | Original file download URL | `browse` |
| `/deviation/whofaved` | GET | Users who faved a deviation | `browse` |
| `/deviation/edit/{deviationid}` | POST | Edit an existing published deviation | `publish` |
| `/deviation/journal` | POST | Create a journal post | `publish` |
| `/deviation/journal/update/{deviationid}` | POST | Update journal | `publish` |
| `/deviation/literature` | POST | Create a literature deviation | `publish` |
| `/deviation/literature/update/{deviationid}` | POST | Update literature | `publish` |

---

## Sta.sh (staging area for unpublished art)

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/stash/submit` | POST (multipart/form-data) | Upload file to Sta.sh; returns `{ itemid, stack, stackid }` | `stash` |
| `/stash/publish` | POST (form) | **Publish a Sta.sh item — `itemid` in body, NOT path** | `publish` |
| `/stash/publish/categorytree` | GET | Browse publishable categories | `publish` |
| `/stash/publish/userdata` | GET | User's previously used tags, licenses | `publish` |

### `/stash/submit` body (multipart)

`title`, `artist_comments`, `tags[]`, `original_url`, `is_dirty`, `file`, `itemid` (overwrite existing), `stack`, `stackid`, `noai`, `is_ai_generated`.

### `/stash/publish` body (form-urlencoded)

**Required:** `itemid`.
**Optional:** `is_mature`, `mature_level` (`strict`|`moderate`), `mature_classification[]`, `feature`, `allow_comments`, `display_resolution` (0-8), `license_options{}`, `allow_free_download`, `add_watermark`, `galleryids[]`, `catpath` (category), `location_tag`, `is_ai_generated`, `noai`, `subject_tags[]`.

Error codes: 0=must accept submission policy, 1=must accept TOS, 2=category not found, 3=invalid category, 4=invalid license, 5=invalid display_resolution, 6=publication failed, 7=deviation not found, 8=preview required, 9=already published.

### **NO Sta.sh listing endpoint**

There is no public endpoint to list current Sta.sh items. Current `getStashContents` stub is correct — the API does not expose it.

---

## User Posts / Status Updates

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/user/posts/{username}` | GET | List user's status posts | `browse` |
| `/user/statuses/post` | POST | Post a new status update | `user.manage` |

---

## Messages & Feedback

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/messages/feed` | GET | Aggregated feed | `message` |
| `/messages/feedback` | GET | Favs/comments/replies | `message` |
| `/messages/feedback/{type}/{stackid}` | GET | Single feedback stack | `message` |
| `/messages/mentions` | GET | Mentions feed | `message` |
| `/messages/mentions/{stackid}` | GET | Single mention stack | `message` |
| `/messages/delete` | POST | Delete message(s) | `message` |

---

## Comments

| Endpoint | Method | Purpose | Scope |
|---|---|---|---|
| `/comments/deviation/{deviationid}` | GET | Deviation comments | `browse` |
| `/comments/profile/{username}` | GET | Profile comments | `browse` |
| `/comments/status/{statusid}` | GET | Status comments | `browse` |
| `/comments/{commentid}/siblings` | GET | Comment thread context | `browse` |
| `/comments/post/deviation/{deviationid}` | POST | Comment on deviation | `comment.post` |
| `/comments/post/profile/{username}` | POST | Comment on profile | `comment.post` |
| `/comments/post/status/{statusid}` | POST | Comment on status | `comment.post` |

---

## Collections (Favorites)

`/collections/all`, `/collections/{folderid}`, `/collections/folders`, `/collections/fave`, `/collections/unfave`, plus folder CRUD parallel to gallery folders.

---

## Pagination convention

Standard cursor: `offset`, `limit` query params. Response includes `has_more` and `next_offset`. Max `limit` varies by endpoint (24 for gallery, 50 for watchers, etc.).
