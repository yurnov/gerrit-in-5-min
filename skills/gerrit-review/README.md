# gerrit-review — Agent Skill

An AI agent skill for interacting with **Gerrit Code Review** via its REST API. Install it into your coding agent to query changes, read diffs, post reviews, and manage the full change lifecycle — all without leaving your editor.

[![Install Skill](https://img.shields.io/badge/skills.sh-install-blue)](https://skills.sh/yurnov/gerrit-in-5-min/gerrit-review)

## Requirements

### Runtime and Dependencies
- OS: Linux
- Shell: Bash with `set -euo pipefail`
- Required tools:
  - `curl`
  - `jq`
  - `base64`
- Optional (preferred for URL encoding):
  - `python3` (`urllib.parse.quote`)
- Fallback URL encoding must still work without Python (basic `/` and space encoding).

### Access to Gerrit
- Gerrit URL
- Valid credentials, provided through either:
  - `~/.netrc` for the Gerrit host (**recommended**)
  - `GERRIT_USERNAME` and `GERRIT_HTTP_PASSWORD` environment variables


## Install

```bash
npx skills add yurnov/gerrit-in-5-min
```

This works for **30+ AI agents** including Claude Code, Cursor, Codex, Antigravity, Windsurf, Copilot, OpenHands, and more.

To install to a specific agent only:

```bash
# Claude Code
npx skills add yurnov/gerrit-in-5-min --skill gerrit-review -a claude-code

# Antigravity (Google Deepmind)
npx skills add yurnov/gerrit-in-5-min --skill gerrit-review -a antigravity

# Cursor
npx skills add yurnov/gerrit-in-5-min --skill gerrit-review -a cursor

# Codex
npx skills add yurnov/gerrit-in-5-min --skill gerrit-review -a codex
```

## Configuration

The helper script checks credentials in this order:

1. `~/.netrc` (**recommended**)
2. `GERRIT_USERNAME` and `GERRIT_HTTP_PASSWORD` environment variables

`GERRIT_URL` is always required:

```bash
export GERRIT_URL="https://gerrit.example.com"
```

### Option 1 — `.netrc` (preferred)

Add an entry for your Gerrit host:

```text
machine gerrit.example.com
login your.username
password your-http-token
```

Then secure the file:

```bash
chmod 600 ~/.netrc
```

This keeps credentials out of the process list and shell environment because the script uses `curl --netrc`.

### Option 2 — Environment Variables (fallback)

If the Gerrit host is not present in `~/.netrc`, set:

| Variable | Description | Where to Get It |
|---|---|---|
| `GERRIT_USERNAME` | Your Gerrit HTTP username | Gerrit → Settings → Profile |
| `GERRIT_HTTP_PASSWORD` | Your Gerrit HTTP credential token | Gerrit → Settings → **HTTP Credentials** → Generate Password |

> **Note:** `GERRIT_HTTP_PASSWORD` is **not** your login password. It is a separate token generated in the Gerrit web UI.

```bash
export GERRIT_USERNAME="your.username"
export GERRIT_HTTP_PASSWORD="your-http-token"
```

## Supported Operations

The skill (and the included helper script) support:

1. **Query changes** — search with Gerrit query syntax (`status:open+owner:self`, etc.)
2. **Get change details** — full metadata, labels, reviewers, current revision
3. **List modified files** — for any revision / patch set
4. **Get file diff** — per-file diff with line ranges
5. **Get file content** — raw decoded content of any file in the change
6. **List published comments** — inspect review feedback already posted on a change
7. **Create draft comments** — stage line comments before publishing them
8. **Post a review** — set labels (`Code-Review`, `Verified`) and inline comments
9. **Submit a change** — merge when requirements are met
10. **Abandon / Restore** — manage change lifecycle with optional message
11. **Add reviewer** — add reviewer or CC to a change
12. **Set topic** — label changes for grouping

## Helper Script Usage

The `scripts/gerrit_api.sh` script wraps REST API calls with authentication, XSSI stripping, JSON formatting, URL encoding, and base64 decoding for file content.

```bash
chmod +x skills/gerrit-review/scripts/gerrit_api.sh
cd skills/gerrit-review

# Query open changes assigned for review
./scripts/gerrit_api.sh query "status:open+reviewer:self+-owner:self"

# Inspect a change
./scripts/gerrit_api.sh get-change 12345
./scripts/gerrit_api.sh list-files 12345
./scripts/gerrit_api.sh get-diff 12345 "src/main/App.java"
./scripts/gerrit_api.sh get-content 12345 "src/main/App.java"
./scripts/gerrit_api.sh list-comments 12345

# Create a draft comment, then publish it in a review
./scripts/gerrit_api.sh create-draft 12345 current \
  '{"path":"src/main/App.java","line":23,"message":"Consider renaming this.","unresolved":true}'

# Post a review with labels and optional inline comments
./scripts/gerrit_api.sh review 12345 current \
  '{"message":"Looks good!","labels":{"Code-Review":1}}'

# Manage lifecycle and metadata
./scripts/gerrit_api.sh submit 12345
./scripts/gerrit_api.sh abandon 12345 "Superseded by #12346"
./scripts/gerrit_api.sh restore 12345
./scripts/gerrit_api.sh add-reviewer 12345 reviewer@example.com
./scripts/gerrit_api.sh set-topic 12345 feature-cleanup
```

## Reviewing Follow-Up Patch Sets

`list-comments` is especially useful when a change already has review history and you need to evaluate the latest patch set in context.

Use it first to retrieve previously published comments:

```bash
./scripts/gerrit_api.sh list-comments 12345
```

Then review the latest patch set against that history:

```bash
./scripts/gerrit_api.sh list-files 12345 current
./scripts/gerrit_api.sh get-diff 12345 "src/main/App.java" current
./scripts/gerrit_api.sh get-content 12345 "src/main/App.java" current
```

Recommended approach:

1. Read earlier comments and identify the actionable ones.
2. Check the latest diff and current file content for the same files and code regions.
3. Decide whether each prior concern was fully addressed, partially addressed, or not addressed.
4. Avoid repeating resolved comments; for remaining issues, post a focused follow-up and use `in_reply_to` if you are continuing an existing thread.

## REST API Notes

- Authenticated Gerrit REST endpoints use the `/a/` prefix.
- Gerrit JSON responses start with the XSSI prefix `)]}'`; the helper script strips it automatically.
- Change IDs can be a numeric change number, `project~branch~Change-Id`, or just the `Change-Id`.
- File paths are URL-encoded automatically by the helper script.

## Manual Installation

If you prefer not to use `npx skills add`, copy the files manually to the appropriate path for your agent:

| Agent | Local project path | Global path |
|---|---|---|
| Antigravity | `.agent/skills/gerrit-review/` | `~/.gemini/antigravity/skills/gerrit-review/` |
| Claude Code | `.claude/skills/gerrit-review/` | `~/.claude/skills/gerrit-review/` |
| Cursor | `.agents/skills/gerrit-review/` | `~/.cursor/skills/gerrit-review/` |
| Codex | `.agents/skills/gerrit-review/` | `~/.codex/skills/gerrit-review/` |
| Windsurf | `.windsurf/skills/gerrit-review/` | `~/.codeium/windsurf/skills/gerrit-review/` |
| Copilot | `.agents/skills/gerrit-review/` | `~/.copilot/skills/gerrit-review/` |
| Cline | `.agents/skills/gerrit-review/` | `~/.agents/skills/gerrit-review/` |

Copy these files to the target path:
- `SKILL.md` (required)
- `scripts/gerrit_api.sh` (optional but recommended)

## Compatibility

Tested with Gerrit 3.x and above. The REST API used (`/a/changes/`, `/a/changes/{id}/revisions/{rev}/review`, etc.) has been stable since Gerrit 2.14.

## Troubleshooting

| Problem | Solution |
|---|---|
| `No credentials found` | Add the Gerrit host to `~/.netrc` or set `GERRIT_USERNAME` and `GERRIT_HTTP_PASSWORD`. |
| `401 Unauthorized` | Verify the `.netrc` entry or regenerate the HTTP credential token in Gerrit Settings. |
| `404 Not Found` | Check the change ID and ensure `GERRIT_URL` has no trailing slash. |
| JSON parse error | Gerrit likely returned the XSSI prefix; use the helper script or strip the first line before piping to `jq`. |

## References

- [Gerrit REST API Documentation](https://gerrit-review.googlesource.com/Documentation/rest-api.html)
- [Gerrit Changes REST API](https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html)
- [skills.sh — Agent Skills Directory](https://skills.sh)
- [Gerrit in 5 Minutes](https://github.com/yurnov/gerrit-in-5-min)