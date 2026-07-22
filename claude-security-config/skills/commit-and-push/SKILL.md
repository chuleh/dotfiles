---
name: commit-and-push
description: Stage all changed and new files, commit them, and push to origin on the current branch. ONLY invoke when the user explicitly types /commit-and-push — never as part of an auto-run workflow.
---

# Commit and Push

Stage all working-tree changes, commit, and push to `origin/<current-branch>` in one shot — without per-step approval prompts.

## When to run

Only when the user has just typed `/commit-and-push`. Never run this as a follow-up step to other work, even if it seems implied. If the user said "ship this" or "push my changes" without invoking the skill, ask first — do NOT call this skill on your own.

## Steps

1. **Inspect state.** Run in parallel:
   - `git status` — what's changed/untracked
   - `git diff` and `git diff --staged` — what's being included
   - `git log -5 --oneline` — match the repo's commit-message style
   - `git branch --show-current` — confirm branch

2. **Sanity checks.** Stop and ask the user before continuing if:
   - Working tree is clean (nothing to do).
   - Branch is `main`/`master` (the wrapper will refuse anyway).
   - Untracked files look like secrets (`.env*`, `*credentials*`, `*.pem`, `id_rsa*`, etc.).
   - A merge/rebase is in progress.

3. **Draft the commit message.** One concise subject line focused on *why*, matching the repo's style from `git log`. No `Co-Authored-By` unless the repo's history already uses it.

4. **Run the wrapper.** This single call stages, commits, and pushes:
   ```
   ~/.claude/bin/commit-and-push.sh "<commit message>"
   ```
   The wrapper is allowlisted, so no prompts. It internally runs `git add -A`, `git commit`, and `git push` (with `-u` if no upstream).

5. **Report.** Show the user the commit SHA and the branch pushed to.

## Failure modes

- **Push rejected (non-fast-forward):** wrapper exits non-zero. Stop, surface the error, ask the user how to proceed. **Never** force-push.
- **Pre-commit hook fails:** the commit didn't happen. Fix the underlying issue, then re-invoke `/commit-and-push` — never use `--no-verify`.
- **On `main`/`master`:** wrapper refuses by design. Tell the user to switch to a feature branch.
