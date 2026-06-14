---
name: gerrit-review
description: Interact with Gerrit Code Review via the REST API — query changes, fetch diffs, post reviews with labels and inline comments, and manage change lifecycle.
license: Apache-2.0
compatibility: Requires git, curl, jq, and base64. Optional python3 for URL encoding.
metadata:
  author: Yuriy Novostavskyy (@yurnov)
  version: "1.2"
  keywords: [gerrit, code review, code review automation, developer tools]
---

# Gerrit Code Review Skill

Interact with a Gerrit Code Review instance through its REST API. Query open changes, read diffs, post code reviews, and manage change lifecycle (submit, abandon, restore).

## Prerequisites

### Authentication

The helper script checks credentials in this order:

1. **`~/.netrc` file (recommended)** — most secure; credentials stay out of the process list and environment.
2. **Environment variables** — fallback when `.netrc` is not configured for the Gerrit host.

`GERRIT_URL` is always required (set it in your shell profile):

```bash
export GERRIT_URL="https://gerrit.example.com"  # no trailing slash
```

#### Option 1 — `.netrc` (preferred)

Add an entry to `~/.netrc` for your Gerrit host:

```
machine gerrit.example.com
login your.username
password your-http-token
```

Secure the file: `chmod 600 ~/.netrc`

The script uses `curl --netrc`, so no credentials appear in the process list or shell environment.

#### Option 2 — Environment Variables (fallback)

If the Gerrit host is not found in `~/.netrc`, the script falls back to:

| Variable | Description |
|---|---|
| `GERRIT_USERNAME` | HTTP username (Gerrit → Settings → Profile) |
| `GERRIT_HTTP_PASSWORD` | HTTP credential token (Gerrit → Settings → HTTP Credentials → Generate Password) |

> [!IMPORTANT]
> The **HTTP password** is NOT the user's login password. It is a separate token generated in the Gerrit web UI under **Settings → HTTP Credentials → Generate Password**.

If neither `.netrc` nor environment variables are configured, the script exits with an error and instructions.

**When guiding users:** always suggest `.netrc` first. Only recommend environment variables if the user cannot use `.netrc`.

### Tools

- `curl`, `jq`, `base64` — required
- `python3` — optional, preferred for URL encoding; falls back to `sed`

## Quick Start

Use the helper script at `scripts/gerrit_api.sh` (relative to this SKILL.md):

```bash
chmod +x scripts/gerrit_api.sh

./scripts/gerrit_api.sh query "status:open+limit:5"
./scripts/gerrit_api.sh get-change 12345
./scripts/gerrit_api.sh list-files 12345
./scripts/gerrit_api.sh get-diff 12345 "src/main/App.java"
./scripts/gerrit_api.sh get-content 12345 "src/main/App.java"
./scripts/gerrit_api.sh list-comments 12345
./scripts/gerrit_api.sh create-draft 12345 current '{"path":"src/main/App.java","line":23,"message":"Consider renaming this.","unresolved":true}'
./scripts/gerrit_api.sh review 12345 current '{"message":"Looks good!","labels":{"Code-Review":1}}'
./scripts/gerrit_api.sh submit 12345
./scripts/gerrit_api.sh abandon 12345
```

## Gerrit Concepts

- **Change** — a single reviewable unit (one commit). Each update creates a new **patch set**.
- **Change-Id** — `Change-Id: I<hex>` footer in the commit message linking commits to Gerrit changes.
- **Labels** — `Code-Review` (−2 to +2), `Verified` (−1 to +1). Ranges are project-specific.
- **Workflow** — push to `refs/for/<branch>` → reviewers comment and vote → amend and re-push → submit when approved.

## REST API Reference

### Authentication

All requests use the `/a/` prefix. Authentication is handled by the helper script automatically (`.netrc` or `--user`).

Raw curl example (for reference):
```bash
curl -s --netrc "$GERRIT_URL/a/changes/?q=status:open" | tail -n +2 | jq .
```

### Output Format

Responses start with an XSSI prefix `)]}'` on the first line. Strip it before parsing (`tail -n +2`). The helper script handles this automatically.

### URL Encoding

Project names and file paths must be URL-encoded (`/` → `%2F`). The helper script handles this automatically.

### Key Endpoints

| # | Operation | Method | Endpoint | Helper command |
|---|---|---|---|---|
| 1 | Query changes | GET | `/a/changes/?q=<query>&n=<limit>&o=<option>` | `query` |
| 2 | Get change details | GET | `/a/changes/<id>?o=CURRENT_REVISION&o=DETAILED_LABELS` | `get-change` |
| 3 | List files | GET | `/a/changes/<id>/revisions/<rev>/files/` | `list-files` |
| 4 | Get file diff | GET | `/a/changes/<id>/revisions/<rev>/files/<file>/diff` | `get-diff` |
| 5 | Get file content | GET | `/a/changes/<id>/revisions/<rev>/files/<file>/content` | `get-content` |
| 6 | List published comments | GET | `/a/changes/<id>/comments` | `list-comments` |
| 7 | Post review | POST | `/a/changes/<id>/revisions/<rev>/review` | `review` |
| 8 | Create draft | PUT | `/a/changes/<id>/revisions/<rev>/drafts` | `create-draft` |
| 9 | Submit | POST | `/a/changes/<id>/submit` | `submit` |
| 10 | Abandon | POST | `/a/changes/<id>/abandon` | `abandon` |
| 11 | Restore | POST | `/a/changes/<id>/restore` | `restore` |
| 12 | Add reviewer | POST | `/a/changes/<id>/reviewers` | `add-reviewer` |
| 13 | Set topic | PUT | `/a/changes/<id>/topic` | `set-topic` |

`<id>` can be a numeric change number, `project~branch~Change-Id`, or just the Change-Id.
`<rev>` is a revision/patch set — use `current` for the latest.

#### Query Operators

`status:open`, `status:merged`, `status:abandoned`, `owner:self`, `reviewer:self`, `project:<name>`, `branch:<name>`, `is:watched`, `after:"2025-01-01"`, `before:"2025-12-31"`

Common `o` parameters: `CURRENT_REVISION`, `DETAILED_LABELS`, `DETAILED_ACCOUNTS`, `CURRENT_FILES`, `MESSAGES`

#### ReviewInput JSON (for `review` command)

```json
{
  "message": "Overall review comment",
  "labels": {"Code-Review": 1},
  "comments": {
    "src/main/App.java": [
      {"line": 23, "message": "Consider renaming.", "unresolved": true},
      {"range": {"start_line": 50, "start_character": 0, "end_line": 55, "end_character": 20}, "message": "Refactor this block."}
    ]
  },
  "notify": "OWNER",
  "drafts": "PUBLISH"
}
```

Label values (typical): Code-Review `−2` reject, `−1` looks wrong, `0` no score, `+1` looks good, `+2` approved. Verified `−1` fails, `+1` verified.

Additional `comments` fields: `in_reply_to` (UUID), `unresolved` (boolean — `true` for actionable, `false` for informational), `fix_suggestions` (array of suggested fixes).

#### CommentInput JSON (for `create-draft` command)

```json
{"path": "src/main/App.java", "line": 23, "message": "[nit] trailing whitespace", "unresolved": true}
```

## Code Review Workflow

### Step 1 — Find changes
```bash
./scripts/gerrit_api.sh query "status:open+reviewer:self+-owner:self"
```

### Step 2 — Inspect
```bash
./scripts/gerrit_api.sh get-change 12345
./scripts/gerrit_api.sh list-files 12345
./scripts/gerrit_api.sh get-diff 12345 "path/to/file.java"
```

### Step 2a — Reuse previous review comments as context

Before reviewing a new patch set, inspect previously published comments:

```bash
./scripts/gerrit_api.sh list-comments 12345
```

Use those comments as additional review context:

- focus on earlier actionable comments (`unresolved: true`, design concerns, requested tests, naming, API changes)
- check the latest patch set diff and current file content for the commented paths
- decide whether each prior concern is fully addressed, partially addressed, or still missing
- avoid repeating resolved comments; for remaining issues, reference the earlier thread with `in_reply_to` when appropriate

Typical follow-up flow:

```bash
./scripts/gerrit_api.sh list-comments 12345
./scripts/gerrit_api.sh list-files 12345 current
./scripts/gerrit_api.sh get-diff 12345 "path/to/file.java" current
./scripts/gerrit_api.sh get-content 12345 "path/to/file.java" current
```

When checking whether previous comments are addressed in the latest patch set, compare:

1. the original concern in `list-comments`
2. the current patch set diff for the same file/region
3. the current file content after the patch set

If the latest patch set resolves the concern, do not re-raise it. If it only partially resolves the issue, post a focused follow-up comment explaining what still remains.

### Step 3 — Post review

**Option A — Incremental drafts:** create drafts one by one, then publish:
```bash
./scripts/gerrit_api.sh create-draft 12345 current '{"path":"file.java","line":42,"message":"Use a constant.","unresolved":true}'
./scripts/gerrit_api.sh review 12345 current '{"message":"See comments.","labels":{"Code-Review":-1},"drafts":"PUBLISH"}'
```

**Option B — Single-step review:** post everything at once:
```bash
./scripts/gerrit_api.sh review 12345 current '{"message":"Looks solid.","labels":{"Code-Review":1},"comments":{"file.java":[{"line":42,"message":"Use a constant.","unresolved":true}]}}'
```

### Step 4 — Submit
```bash
./scripts/gerrit_api.sh submit 12345
```

## Troubleshooting

| Problem | Solution |
|---|---|
| `401 Unauthorized` | Check `.netrc` entry or `GERRIT_USERNAME`/`GERRIT_HTTP_PASSWORD`. Re-generate the HTTP password in Gerrit Settings. |
| `404 Not Found` | Verify change number. Check `GERRIT_URL` has no trailing slash. Ensure `/a/` prefix. |
| `409 Conflict` | May be reviewing a change edit, or submit requirements not met. |
| JSON parse error | Ensure XSSI prefix `)]}'\n` is stripped (helper script does this). |
| URL encoding issues | Paths with `/` need `%2F`. The helper script handles this. |
| No credentials error | Add Gerrit host to `~/.netrc` (preferred) or set env vars. |

## Awareness

- `GERRIT_URL` can appear in output, but **never** print `GERRIT_HTTP_PASSWORD` or credentials in logs or outputs.
- Ensure `~/.netrc` has `chmod 600` permissions.
- This skill is for interactive use and may not cover all Gerrit API edge cases.

## References

- [Gerrit REST API Documentation](https://gerrit-review.googlesource.com/Documentation/rest-api.html)
- [Gerrit Changes REST API](https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html)
- [Gerrit Search Operators](https://gerrit-review.googlesource.com/Documentation/user-search.html)
- [Gerrit in 5 Minutes](https://github.com/yurnov/gerrit-in-5-min)