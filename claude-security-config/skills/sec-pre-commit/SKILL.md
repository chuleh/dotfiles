---
name: sec-pre-commit
description: Set up security-focused pre-commit hooks (secret scanning plus IaC/code scanners) in the current repo using the pre-commit framework. Use when the user wants commit-time secret detection, to add gitleaks/tfsec/checkov/bandit/hadolint hooks, set up pre-commit, or shift security scanning left. Adapted from mattpocock/skills setup-pre-commit, retargeted to security tooling.
---

# Security Pre-Commit Hooks

Set up commit-time security scanning with the `pre-commit` framework (https://pre-commit.com). Secret scanning is always installed; the rest are added only for stacks actually present in the repo. This is a defense-in-depth layer that complements, not replaces, CI scanning and the `block-dangerous-git.sh` guardrail hook.

## 1. Detect what the repo contains

Check the repo before choosing hooks. Only add a scanner if its stack is present:

- `*.tf` / `*.tfvars` -> Terraform scanners
- `*.py` / `pyproject.toml` / `requirements*.txt` -> Python scanners
- `Dockerfile*` / `*.dockerfile` -> Docker linter
- `*.yaml`/`*.yml` manifests under `k8s/`, `manifests/`, `charts/`, `deploy/` -> Kubernetes scanner
- `.github/workflows/*` -> Actions scanner

## 2. Confirm before installing

State which hooks you will add and why, then confirm with the user. Do not silently add scanners for stacks they did not ask about.

## 3. Write `.pre-commit-config.yaml`

Always include the baseline. Add the stack blocks that apply. Keep only what is relevant — do not add speculative hooks.

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files
      - id: check-merge-conflict
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_trivy
      - id: terraform_checkov
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.10
    hooks:
      - id: bandit
        args: ["-c", "pyproject.toml"]
  - repo: https://github.com/hadolint/hadolint
    rev: v2.13.1
    hooks:
      - id: hadolint-docker
```

For Kubernetes manifests, add `bridgecrewio/checkov` (`id: checkov`) scoped to the manifest paths; for `.github/workflows`, add `rhysd/actionlint`.

## 4. Pin to commit SHAs

CLAUDE.md forbids floating versions. The `rev` values above are tags at authoring time and may be stale. After writing the file, look up the latest released tag for each repo, then freeze to immutable SHAs:

```bash
pre-commit autoupdate --freeze
```

This rewrites each `rev` to a full commit SHA with the tag in a trailing comment.

## 5. Install and smoke-test

```bash
pre-commit install
pre-commit run --all-files
```

Triage findings with the user. Real secrets must be removed from history, not just unstaged — flag this and stop if `gitleaks` fires on committed content.

## 6. Verify

- [ ] `.pre-commit-config.yaml` exists with `gitleaks` + `detect-private-key`
- [ ] Every `rev` is a pinned SHA (no branch names, no `latest`)
- [ ] Only stacks present in the repo have scanners
- [ ] `pre-commit install` created `.git/hooks/pre-commit`
- [ ] `pre-commit run --all-files` completes and findings are triaged

## Notes

- Secret scanning is name- and content-based here; the `block-dangerous-git.sh` hook is name-based only. They are complementary.
- `pre-commit` is language-agnostic, which is why it is preferred over Husky for this multi-stack security context.
- Local hooks can be bypassed with `git commit --no-verify`. Keep the same scanners in CI so the control is enforced where it cannot be skipped.
