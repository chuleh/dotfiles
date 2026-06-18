#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

block() {
  echo "BLOCKED: $1 The user has prevented you from doing this." >&2
  exit 2
}

DANGEROUS_PATTERNS=(
  "git push"
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "reset --hard"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    block "'$COMMAND' matches dangerous pattern '$pattern'."
  fi
done

secret_match() {
  echo "$1" | grep -qiE '\.(pem|key|p12|pfx|keystore|jks)([^a-z]|$)|(^|[/ ])id_(rsa|dsa|ecdsa|ed25519)([^a-z]|$)|credentials|client_secret|service[-_]account[^ ]*\.json' && return 0
  echo "$1" | grep -iE '(^|[/ ])\.env[^ ]*' | grep -qvE '\.env\.(example|sample|template|dist|defaults)' && return 0
  return 1
}

if echo "$COMMAND" | grep -qE "git +(add|commit)" && secret_match "$COMMAND"; then
  block "'$COMMAND' looks like it stages or commits a secret-bearing file (.env, key/cert, credentials)."
fi

if echo "$COMMAND" | grep -qE "git +commit"; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    block "committing directly to '$BRANCH' is not allowed. Create a feature branch first."
  fi
  STAGED=$(git diff --cached --name-only 2>/dev/null)
  if [ -n "$STAGED" ] && secret_match "$STAGED"; then
    block "staged files include a likely secret (matched by filename). Unstage it before committing."
  fi
fi

exit 0
