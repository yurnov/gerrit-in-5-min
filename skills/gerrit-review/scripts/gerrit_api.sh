#!/usr/bin/env bash
#
# Copyright 2026 Yuriy Novostavskyy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# gerrit_api.sh — Gerrit REST API helper
#
# Authentication (checked in order):
#   1. ~/.netrc  — preferred; entry for the Gerrit host (see curl --netrc)
#   2. Environment variables GERRIT_USERNAME + GERRIT_HTTP_PASSWORD
#
# Required:
#   GERRIT_URL — Base URL (e.g. https://gerrit.example.com)
#
# Usage: ./gerrit_api.sh <command> [args...]
#
# Commands:
#   query         <query-string> [options...]   Query for changes
#   get-change    <change-id> [options...]       Get change details
#   list-files    <change-id> [revision]         List modified files
#   get-diff      <change-id> <file> [revision]  Get file diff
#   get-content   <change-id> <file> [revision]  Get raw file content
#   list-comments <change-id>                    List all published comments
#   create-draft  <change-id> <revision> <json>  Create a draft comment
#   review        <change-id> <revision> <json>  Post a review
#   submit        <change-id>                    Submit a change
#   abandon       <change-id> [message]          Abandon a change
#   restore       <change-id> [message]          Restore a change
#   add-reviewer  <change-id> <account>          Add a reviewer
#   set-topic     <change-id> <topic>            Set the topic
#   help                                         Show this help

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

BASE_URL=""
AUTH_ARGS=()

init_config() {
  if [[ -z "${GERRIT_URL:-}" ]]; then
    echo "ERROR: GERRIT_URL is not set." >&2
    exit 1
  fi

  BASE_URL="${GERRIT_URL%/}"
  local host
  host=$(echo "$BASE_URL" | sed -E 's|https?://||; s|[:/].*||')

  if [[ -f ~/.netrc ]] && grep -q "machine[[:space:]]*${host}" ~/.netrc; then
    AUTH_ARGS=(--netrc)
  elif [[ -n "${GERRIT_USERNAME:-}" && -n "${GERRIT_HTTP_PASSWORD:-}" ]]; then
    AUTH_ARGS=(--user "${GERRIT_USERNAME}:${GERRIT_HTTP_PASSWORD}")
  else
    echo "ERROR: No credentials found for ${host}." >&2
    echo "Either add an entry to ~/.netrc:" >&2
    echo "  machine ${host}" >&2
    echo "  login <username>" >&2
    echo "  password <http-token>" >&2
    echo "Or set GERRIT_USERNAME and GERRIT_HTTP_PASSWORD." >&2
    exit 1
  fi
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

url_encode() {
  python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1" 2>/dev/null \
    || printf '%s' "$1" | sed 's/\//%2F/g; s/ /%20/g'
}

strip_xssi() { tail -n +2; }

gerrit_get() {
  [[ -z "$BASE_URL" ]] && init_config
  local endpoint="$1"; shift
  curl -sf "${AUTH_ARGS[@]}" "$@" "${BASE_URL}/a${endpoint}" | strip_xssi
}

gerrit_post() {
  [[ -z "$BASE_URL" ]] && init_config
  local endpoint="$1" body="${2:-{}}"
  curl -sf "${AUTH_ARGS[@]}" -X POST -H "Content-Type: application/json" \
    -d "$body" "${BASE_URL}/a${endpoint}" | strip_xssi
}

gerrit_put() {
  [[ -z "$BASE_URL" ]] && init_config
  local endpoint="$1" body="${2:-{}}"
  curl -sf "${AUTH_ARGS[@]}" -X PUT -H "Content-Type: application/json" \
    -d "$body" "${BASE_URL}/a${endpoint}" | strip_xssi
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd_query() {
  local query="${1:?Usage: query <query-string> [o=OPTION ...]}"
  shift
  local opts=""
  for opt in "$@"; do opts="${opts}&o=${opt}"; done
  gerrit_get "/changes/?q=${query}&n=25${opts}" | jq .
}

cmd_get_change() {
  local change_id="${1:?Usage: get-change <change-id> [o=OPTION ...]}"
  shift
  if [[ $# -eq 0 ]]; then
    set -- CURRENT_REVISION DETAILED_LABELS DETAILED_ACCOUNTS
  fi
  local opts="o=$1"; shift
  for opt in "$@"; do opts="${opts}&o=${opt}"; done
  gerrit_get "/changes/${change_id}?${opts}" | jq .
}

cmd_list_files() {
  local change_id="${1:?Usage: list-files <change-id> [revision]}"
  local revision="${2:-current}"
  gerrit_get "/changes/${change_id}/revisions/${revision}/files/" | jq .
}

cmd_get_diff() {
  local change_id="${1:?Usage: get-diff <change-id> <file-path> [revision]}"
  local file_path="${2:?Usage: get-diff <change-id> <file-path> [revision]}"
  local revision="${3:-current}"
  gerrit_get "/changes/${change_id}/revisions/${revision}/files/$(url_encode "$file_path")/diff" | jq .
}

cmd_get_content() {
  [[ -z "$BASE_URL" ]] && init_config
  local change_id="${1:?Usage: get-content <change-id> <file-path> [revision]}"
  local file_path="${2:?Usage: get-content <change-id> <file-path> [revision]}"
  local revision="${3:-current}"
  curl -sf "${AUTH_ARGS[@]}" \
    "${BASE_URL}/a/changes/${change_id}/revisions/${revision}/files/$(url_encode "$file_path")/content" \
    | base64 -d
}

cmd_list_comments() {
  local change_id="${1:?Usage: list-comments <change-id>}"
  gerrit_get "/changes/${change_id}/comments" | jq .
}

cmd_create_draft() {
  local change_id="${1:?Usage: create-draft <change-id> <revision> <json-body>}"
  local revision="${2:?Usage: create-draft <change-id> <revision> <json-body>}"
  local json_body="${3:?Usage: create-draft <change-id> <revision> <json-body>}"
  gerrit_put "/changes/${change_id}/revisions/${revision}/drafts" "$json_body" | jq .
}

cmd_review() {
  local change_id="${1:?Usage: review <change-id> <revision> <json-body>}"
  local revision="${2:?Usage: review <change-id> <revision> <json-body>}"
  local json_body="${3:?Usage: review <change-id> <revision> <json-body>}"
  gerrit_post "/changes/${change_id}/revisions/${revision}/review" "$json_body" | jq .
}

cmd_submit() {
  local change_id="${1:?Usage: submit <change-id>}"
  gerrit_post "/changes/${change_id}/submit" '{}' | jq .
}

cmd_abandon() {
  local change_id="${1:?Usage: abandon <change-id> [message]}"
  local message="${2:-}" body='{}'
  [[ -n "$message" ]] && body=$(jq -n --arg msg "$message" '{"message":$msg}')
  gerrit_post "/changes/${change_id}/abandon" "$body" | jq .
}

cmd_restore() {
  local change_id="${1:?Usage: restore <change-id> [message]}"
  local message="${2:-}" body='{}'
  [[ -n "$message" ]] && body=$(jq -n --arg msg "$message" '{"message":$msg}')
  gerrit_post "/changes/${change_id}/restore" "$body" | jq .
}

cmd_add_reviewer() {
  local change_id="${1:?Usage: add-reviewer <change-id> <account>}"
  local reviewer="${2:?Usage: add-reviewer <change-id> <account>}"
  gerrit_post "/changes/${change_id}/reviewers" "$(jq -n --arg r "$reviewer" '{"reviewer":$r}')" | jq .
}

cmd_set_topic() {
  local change_id="${1:?Usage: set-topic <change-id> <topic>}"
  local topic="${2:?Usage: set-topic <change-id> <topic>}"
  gerrit_put "/changes/${change_id}/topic" "$(jq -n --arg t "$topic" '{"topic":$t}')" | jq .
}

cmd_help() {
  sed -n '2,/^$/{ s/^# *//; p }' "$0"
  echo ""
  echo "Commands:"
  echo "  query         <query-string> [options...]   Query for changes"
  echo "  get-change    <change-id> [options...]       Get change details"
  echo "  list-files    <change-id> [revision]         List modified files"
  echo "  get-diff      <change-id> <file> [revision]  Get file diff"
  echo "  get-content   <change-id> <file> [revision]  Get raw file content"
  echo "  list-comments <change-id>                    List all published comments"
  echo "  create-draft  <change-id> <revision> <json>  Create a draft comment"
  echo "  review        <change-id> <revision> <json>  Post a review"
  echo "  submit        <change-id>                    Submit a change"
  echo "  abandon       <change-id> [message]          Abandon a change"
  echo "  restore       <change-id> [message]          Restore a change"
  echo "  add-reviewer  <change-id> <account>          Add a reviewer"
  echo "  set-topic     <change-id> <topic>            Set the topic"
  echo "  help                                         Show this help"
}

# ─── Main dispatcher ─────────────────────────────────────────────────────────

command="${1:-help}"
shift || true

case "$command" in
  query)        cmd_query "$@" ;;
  get-change)   cmd_get_change "$@" ;;
  list-files)   cmd_list_files "$@" ;;
  get-diff)     cmd_get_diff "$@" ;;
  get-content)  cmd_get_content "$@" ;;
  list-comments) cmd_list_comments "$@" ;;
  create-draft) cmd_create_draft "$@" ;;
  review)       cmd_review "$@" ;;
  submit)       cmd_submit "$@" ;;
  abandon)      cmd_abandon "$@" ;;
  restore)      cmd_restore "$@" ;;
  add-reviewer) cmd_add_reviewer "$@" ;;
  set-topic)    cmd_set_topic "$@" ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "ERROR: Unknown command '${command}'" >&2
    echo "Run '$(basename "$0") help' for usage." >&2
    exit 1
    ;;
esac
