# Gerrit in a few minutes

A short introduction to Gerrit for developers familiar with git (GitHub, GitLab, Gitea) who are starting to use Gerrit.

## Gerrit in one sentence

Gerrit is a web-based code-review and project-management tool that acts as a gatekeeper for git repositories: instead of pushing commits directly to branches, developers push reviewable "changes" (patch sets) to Gerrit. Gerrit tracks reviews, labels (e.g., Code-Review, Verified) and performs the submit/merge into the target branch once the required approvals are present.

Gerrit uses a Change-Id to group related patch sets. Ensure the Change-Id is present in the commit message — installing the `commit-msg` hook is strongly recommended after cloning a project:

```
git clone ssh://gerrithost:29418/mysuperproject.git \
    && (cd mysuperproject && mkdir -p "$(git rev-parse --git-dir)/hooks" \
    && curl -Lo "$(git rev-parse --git-dir)/hooks/commit-msg" https://gerrithost/tools/hooks/commit-msg \
    && chmod +x "$(git rev-parse --git-dir)/hooks/commit-msg")
```

## Gerrit under the hood (optional)

When a "change" is pushed for review, Gerrit stores it under `refs/changes/`. The ref format is:

```
refs/changes/X/Y/Z
```

- X = last two digits of the change number
- Y = the full change number
- Z = the patch set number

A change contains a Change-Id, metadata (owner, project, target branch), one or more patch sets, comments and votes. Each patch set is a git commit; only the latest patch set can be submitted. Clients can fetch a specific change ref locally for verification.

## Workflow overview

1. Make a local commit. Gerrit treats each commit as a reviewable change (the `commit-msg` hook will add the Change-Id).
2. Push the commit to Gerrit’s staging area (not directly to the branch). For example, to target the main branch:
     ```
     git push origin HEAD:refs/for/main
     ```
     Replace `main` with your project's default branch (often `main` or `master`). Gerrit returns a link to the change in the web UI.
3. Review cycle: reviewers add comments and labels (e.g., Code-Review +2, Verified +1 from CI).
4. Update your change if requested: edit files, stage them, then amend the commit to keep the same Change-Id:
     - Preserve Change-Id but update content:
         ```
         git add .
         git commit --amend
         ```
     - Create a new patch set without changing the commit message:
         ```
         git commit --amend --no-edit
         ```
     Push again with the same command; Gerrit creates a new patch set tied to the same Change-Id. Repeat review/update as needed.
5. Submit: when required labels and CI checks are satisfied, a committer clicks SUBMIT; Gerrit merges according to the project’s submit strategy.

## Review is optional

Code review can be optional in some workflows. Certain commits—often produced by CI/CD or automated jobs—may be pushed directly to branches without going through Gerrit's review queue.

Differences between the review and non-review flows are shown in the table below.

| Action | Ref pattern | Gerrit permission(s) | Notes |
|---|---|---|---|
| Push for review | refs/for/* | Push to refs/for/* | Typical developer flow; creates a change that goes through review |
| Direct push (non-review) | refs/heads/* | Direct push / Submit (may require Forge Author or elevated perms) | Usually restricted to repository owners or CI/service accounts; bypasses review and submits directly |

Examples:
- Push for review: `git push origin HEAD:refs/for/main`
- Direct push (no review): `git push origin HEAD:main`

## Cheat sheet

Replace `main` with your repository’s default branch if different.

Ensure you are on the desired branch and have a clean working tree:
```
git reset --hard origin/master && git clean -df && git checkout master \
&& git fetch && git reset --hard origin/master
```

Create and commit changes:
```
vi myfile
git add myfile
git commit -m "[JIRA-123] Subject of my change" -m "Additional information about the change"
```

Push to the target branch (example: main):
```
git push origin HEAD:refs/for/main
```

Push to the currently checked-out branch:
```
git push origin HEAD:refs/for/$(git rev-parse --abbrev-ref HEAD)
```

Amend to create a new patch set without changing the commit message:
```
git commit --amend --no-edit
```

Amend and change the commit message (ensure the Change-Id remains in the message):
```
git commit --amend
```

You can use ready-to-use aliases (see [.bash_aliases](.bash_aliases)). Example workflow using aliases to create a new patch set:
```
gmaster
vi file
git add . && git commit -S -m "my commit msg" && gpush   # first patch set -> new CR
vi file
git add . && gamend && gpush                              # add patch set to existing CR
```

## Advanced topics

- If you remove or change the Change-Id in a commit message, Gerrit will treat the push as a new change rather than a new patch set for an existing change.
- You can intentionally create a new change by using a different Change-Id, or add a new patch set to an existing change by reusing its Change-Id.
- Generate a Change-Id without the hook (example):
    ```
    echo "Change-Id: I$( (whoami; hostname; date; echo $RANDOM) | git hash-object --stdin )"
    ```
    Note: Gerrit’s expected Change-Id format is typically `Change-Id: I<hex>`.

Gerrit also provides a CLI — see the documentation: https://gerrit-review.googlesource.com/Documentation/cmd-index.html

You can control additional options when pushing by appending modifiers to the ref. For example, `refs/for/main%wip` marks the change as Work-In-Progress (WIP), which prevents accidental submission and indicates the change is not ready for review.

Some examples:

| Action | Explanation | Example command |
|---|---|---|
| Mark Work-In-Progress (WIP) | Prevents accidental submission and indicates the change is not ready for review | `git push origin HEAD:refs/for/main%wip` |
| Mark ready for review | Convert a WIP change to ready for review | `git push origin HEAD:refs/for/main%ready` |
| Make change private | Restrict visibility of the change | `git push origin HEAD:refs/for/main%private` |
| Set a topic | Group related changes under a topic name | `git push origin HEAD:refs/for/main%topic=my-feature` |
| Add reviewers / CCs | Auto-add reviewers or CC recipients (comma-separated) | `git push origin HEAD:refs/for/main%reviewer=alice@example.com,cc=bob@example.com` |
| Control notifications | Limit who receives emails/notifications (common values: NONE, OWNER, REVIEWERS, ALL) | `git push origin HEAD:refs/for/main%notify=NONE` |

Notes:
- Multiple modifiers can be combined by separating them with commas, e.g. `%wip,topic=my-feature,notify=OWNER`.
- Supported modifiers and behavior can vary by Gerrit installation; check your project/server documentation for available options and permission requirements.

## References

- https://gerrit-review.googlesource.com/Documentation/intro-gerrit-walkthrough.html
- https://gerrit-review.googlesource.com/Documentation/user-changeid.html
- https://gerrit-review.googlesource.com/Documentation/intro-user.html
- https://gerrit-review.googlesource.com/Documentation/cmd-index.html
