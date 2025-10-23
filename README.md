# Gerrit in a few minutes

A short introduction to Gerrit for developers experienced with git (e.g., GitHub, GitLab, Gitea) who are starting to use Gerrit.

## Gerrit in one sentence

Gerrit is a web-based code-review and project-management tool that acts as a gatekeeper for git repositories: instead of pushing commits directly to branches, developers push reviewable “changes” (patch sets) to Gerrit. Gerrit tracks reviews, labels (e.g., Code-Review, Verified) and performs the submit/merge into the target branch once required approvals are present.

Gerrit uses a Change-Id to identify related patch sets. Ensure the Change-Id is present in the commit message — installing the `commit-msg` hook is strongly recommended as part of the initial project clone:

```
git clone ssh://gerrithost:29418/mysuperproject.git \
    && (cd mysuperproject && mkdir -p "$(git rev-parse --git-dir)/hooks" \
    && curl -Lo "$(git rev-parse --git-dir)/hooks/commit-msg" https://gerrithost/tools/hooks/commit-msg \
    && chmod +x "$(git rev-parse --git-dir)/hooks/commit-msg")
```

## Gerrit under the hood (optional)

When a “change” is pushed for review, Gerrit stores it in a staging area under the `refs/changes/` namespace. The ref format is:

```
refs/changes/X/Y/Z
```

- X = last two digits of the change number
- Y = the full change number
- Z = the patch set number

A change contains a Change-Id, metadata (owner, project, target branch), one or more patch sets, comments and votes. Each patch set is a git commit; the latest patch set is the only one that can be submitted. Clients can fetch a specific change ref locally for verification.

## Workflow overview

1) Make a local commit. Gerrit treats each commit as a reviewable change (the `commit-msg` hook will add the Change-Id).
2) Push the commit to Gerrit’s staging area (not directly to the branch). For example, to target the main branch:
     ```
     git push origin HEAD:refs/for/main
     ```
     Replace `main` with your project's default branch (often `main` or `master`). Gerrit returns a link to the change in the web UI.
3) Review cycle: reviewers add comments and labels (e.g., Code-Review +2, Verified +1 from CI).
4) Update your change if requested: edit files, stage them, then amend the commit to keep the same Change-Id:
     - Preserve Change-Id but update content:
         ```
         git add .
         git commit --amend
         ```
     - Create a new patch set without changing the commit message:
         ```
         git commit --amend --no-edit
         ```
     Push again using the same `git push origin HEAD:refs/for/<branch>` command; Gerrit creates a new patch set tied to the same Change-Id. Repeat review/update as needed.
5) Submit: when required labels and CI checks are satisfied, a committer clicks SUBMIT; Gerrit merges according to the project’s submit strategy.

## Cheat sheet

Replace `main` with your repository’s default branch if different.

Ensure you are on the current branch and clean local state:
```
git fetch origin && git checkout main && git reset --hard origin/main && \
git clean -fd && && git checkout main && git fetch && \
git reset --hard origin/main'
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

Amend and change the commit message (Change-Id must be preserved in the commit message):
```
git commit --amend
```

## Advanced topics

- If you remove or change the Change-Id in a commit message, Gerrit will treat the push as a completely new change instead of a new patch set for an existing change.
- You can intentionally create a new patch set for an existing change by reusing its Change-Id in another commit’s message.
- You can generate a Change-Id without the hook (example):
    ```
    echo "Change-Id: I$( (whoami; hostname; date; echo $RANDOM) | git hash-object --stdin )"
    ```
    Note: Gerrit’s expected Change-Id format is typically `Change-Id: I<hex>`.

Gerrit also provides a CLI; see the documentation for details: https://gerrit-review.googlesource.com/Documentation/cmd-index.html

## References

- https://gerrit-review.googlesource.com/Documentation/intro-gerrit-walkthrough.html
- https://gerrit-review.googlesource.com/Documentation/user-changeid.html
- https://gerrit-review.googlesource.com/Documentation/intro-user.html
- https://gerrit-review.googlesource.com/Documentation/cmd-index.html