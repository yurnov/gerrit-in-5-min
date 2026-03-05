# gerrit-review — Agent Skill

An AI agent skill for interacting with **Gerrit Code Review** via its REST API. Install it into your coding agent to query changes, read diffs, post reviews, and manage the full change lifecycle — all without leaving your editor.

<!-- [![Install Skill](https://img.shields.io/badge/skills.sh-install-blue)](https://skills.sh/yurnov/gerrit-in-5-min/gerrit-review)
 -->
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
- Valid credentials (Gerrit HTTP username and credential token)


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

The skill requires three environment variables. Set them in your shell profile (`.bashrc`, `.zshrc`, etc.):

| Variable | Description | Where to Get It |
|---|---|---|
| `GERRIT_URL` | Base URL of your Gerrit instance | e.g. `https://gerrit.example.com` |
| `GERRIT_USERNAME` | Your Gerrit HTTP username | Gerrit → Settings → Profile |
| `GERRIT_HTTP_PASSWORD` | Your Gerrit HTTP credential token | Gerrit → Settings → **HTTP Credentials** → Generate Password |

> **Note:** `GERRIT_HTTP_PASSWORD` is **not** your login password. It is a separate token generated in the Gerrit web UI.

```bash
export GERRIT_URL="https://gerrit.example.com"
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
6. **Post a review** — set labels (`Code-Review`, `Verified`) and inline comments
7. **Submit a change** — merge when requirements are met
8. **Abandon / Restore** — manage change lifecycle with optional message
9. **Add reviewer** — add reviewer or CC to a change
10. **Set topic** — label changes for grouping

## Helper Script Usage

The `scripts/gerrit_api.sh` script wraps all REST API calls with authentication, JSON formatting, and URL encoding built in.

```bash
chmod +x skills/gerrit-review/scripts/gerrit_api.sh
cd skills/gerrit-review

# Query open changes you own
./scripts/gerrit_api.sh query "status:open+owner:self"

# Inspect a change
./scripts/gerrit_api.sh get-change 12345
./scripts/gerrit_api.sh list-files 12345
./scripts/gerrit_api.sh get-diff 12345 "src/main/App.java"

# Post a +1 code review
./scripts/gerrit_api.sh review 12345 current \
  '{"message":"Looks good!","labels":{"Code-Review":1}}'

# Submit, abandon, restore
./scripts/gerrit_api.sh submit 12345
./scripts/gerrit_api.sh abandon 12345 "Superseded by #12346"
./scripts/gerrit_api.sh restore 12345
```

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

## References

- [Gerrit REST API Documentation](https://gerrit-review.googlesource.com/Documentation/rest-api.html)
- [Gerrit Changes REST API](https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html)
- [skills.sh — Agent Skills Directory](https://skills.sh)
- [Gerrit in 5 Minutes](https://github.com/yurnov/gerrit-in-5-min)