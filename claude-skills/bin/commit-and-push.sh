#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: commit-and-push.sh <commit-message>" >&2
  exit 2
fi

msg="$1"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  echo "error: detached HEAD — refusing to push" >&2
  exit 1
fi

if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "error: refusing to commit/push directly to $branch" >&2
  exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "nothing to commit — working tree clean"
  exit 0
fi

secret_re='(^|/)(\.env(\..+)?|.*credentials.*|.*secret.*|.*\.pem|.*\.key|id_rsa.*|id_ed25519.*|.*\.p12|.*\.pfx|.*\.kdbx|.*\.asc)$'
suspicious="$(git status --porcelain | awk '{print $NF}' | grep -Ei "$secret_re" || true)"
if [[ -n "$suspicious" ]]; then
  echo "error: refusing to commit — these paths look like secrets:" >&2
  echo "$suspicious" >&2
  echo "review and either delete, .gitignore, or commit them manually." >&2
  exit 1
fi

git add -A
git commit -m "$msg"

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push origin "$branch"
else
  git push -u origin "$branch"
fi
