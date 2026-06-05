---
name: sec-github-actions
description: GitHub Actions security guidance — secrets handling, pinning actions to commit SHAs, OIDC over static credentials, minimal permissions, and dangerous-pattern avoidance. Use when creating or editing workflow YAML under .github/workflows.
---

# GitHub Actions Security

## Secrets Management
- **ALWAYS use GitHub Secrets** for credentials
- Never log secrets (even masked, avoid `echo` with secrets)
- Use environment-specific secrets
- Warn if using a secret over 90 days old. If user ACKs move on

## Workflow Security
```yaml
# GOOD - Minimal permissions
permissions:
  contents: read
  pull-requests: write

# Pin actions to commit SHA, not tags
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # v3.5.2

# Use environment protection rules for production
environment:
  name: production
  url: https://example.com
```

## Third-Party Actions
- **Pin actions to full commit SHA** (not tags - they're mutable)
- Audit third-party actions before use
- Prefer official actions from verified creators
- Review action source code for sensitive operations

## OIDC Token Usage
- Prefer OIDC tokens over static credentials for cloud access
- Set minimal token permissions
- Use scoped tokens per job

## Anti-Patterns to Avoid
- `pull_request_target` with untrusted code execution
- Checking out PR code with write permissions
- Using `${{ github.token }}` without permission restrictions
- Disabling security features (code scanning, Dependabot)
