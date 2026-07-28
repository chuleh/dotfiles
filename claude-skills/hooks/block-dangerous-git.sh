#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

block() {
  echo "BLOCKED: $1 The user has prevented you from doing this." >&2
  exit 2
}

runs() {
  echo "$COMMAND" | grep -qE "(^|[;&|(])[[:space:]]*$1"
}

for sub in "git +push" "git +reset +--hard" "git +clean +-f" "git +branch +-D" "git +checkout +\." "git +restore +\."; do
  if runs "$sub"; then
    block "'$COMMAND' matches dangerous git operation '$sub'."
  fi
done

secret_match() {
  echo "$1" | grep -qiE '\.(pem|key|p12|pfx|keystore|jks)([^a-z]|$)|(^|[/ ])id_(rsa|dsa|ecdsa|ed25519)([^a-z]|$)|credentials|client_secret|service[-_]account[^ ]*\.json' && return 0
  echo "$1" | grep -iE '(^|[/ ])\.env[^ ]*' | grep -qvE '\.env\.(example|sample|template|dist|defaults)' && return 0
  return 1
}

git_target_dir() {
  local dir
  dir=$(echo "$1" | grep -oE 'git +-C +[^ ]+' | head -1 | sed -E 's/git +-C +//')
  [ -n "$dir" ] && { echo "$dir"; return; }
  dir=$(echo "$1" | grep -oE '(^|&&|;) *cd +[^ ]+' | head -1 | sed -E 's/.*cd +//')
  [ -n "$dir" ] && { echo "$dir"; return; }
  echo "."
}

if runs "git +(add|commit)" && secret_match "$COMMAND"; then
  block "'$COMMAND' looks like it stages or commits a secret-bearing file (.env, key/cert, credentials)."
fi

if runs "git +commit"; then
  GITDIR=$(git_target_dir "$COMMAND")
  BRANCH=$(git -C "$GITDIR" symbolic-ref --short HEAD 2>/dev/null)
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    block "committing directly to '$BRANCH' is not allowed. Create a feature branch first."
  fi
  STAGED=$(git -C "$GITDIR" diff --cached --name-only 2>/dev/null)
  if [ -n "$STAGED" ] && secret_match "$STAGED"; then
    block "staged files include a likely secret (matched by filename). Unstage it before committing."
  fi
fi

exit 0
