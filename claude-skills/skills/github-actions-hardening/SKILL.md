---
name: github-actions-hardening
description: Use whenever creating, editing, or reviewing GitHub Actions workflows, composite/reusable actions, or related repository CI configuration. Enforces least-privilege, supply-chain-secure, and battle-tested practices (GitHub's hardening guide, OpenSSF Scorecard, SLSA Level 3 expectations, CIS GitHub Benchmark). Trigger on file patterns .github/workflows/*.yml, .github/workflows/*.yaml, action.yml, action.yaml, .github/actions/**, .github/dependabot.yml, CODEOWNERS, and any reusable workflow file.
---

# GitHub Actions Hardening Skill

You are writing or reviewing GitHub Actions. Apply **principle of least privilege**, **supply-chain integrity**, and **defense in depth**. Workflows are remote code execution with access to your secrets and repo — treat them accordingly.

Rules below are non-negotiable defaults — deviate only with explicit, stated reason and call it out.

## How to use this skill

1. Before editing, scan existing workflows for current violations and note them.
2. Apply the rules in the relevant sections.
3. After writing, run the **Self-check** at the bottom and report any rule you knowingly skipped with one-line justification.
4. Suggest running `actionlint`, `zizmor`, `OpenSSF Scorecard`, and `pinact` if not already in CI.

---

## Permissions (least privilege)

- **Always declare top-level `permissions:`.** Default the entire workflow to read-only, then grant per-job what's needed:
  ```yaml
  permissions:
    contents: read
  ```
- Never use `permissions: write-all` or rely on the repo-default permissions.
- Grant write scopes (`contents: write`, `packages: write`, `id-token: write`, `pull-requests: write`, etc.) **at the job level**, not workflow level.
- The `GITHUB_TOKEN` is a credential. Treat scope expansion the same way you'd treat handing out an IAM role.
- Disable `GITHUB_TOKEN` permissions defaults at the org/repo level to "restricted" so missing `permissions:` blocks fail closed.

---

## Pinning third-party actions

- **Pin every third-party action by full commit SHA**, never by tag or branch:
  ```yaml
  - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
  ```
  Add the human-readable version as a trailing comment so Dependabot/Renovate can update it.
- First-party `actions/*` and `github/*` may be tag-pinned only if the org has explicitly approved it; SHA-pinning is still preferred.
- **Never** pin to a moving ref: `@main`, `@master`, `@v1`, `@latest`. A tag can be re-pointed; a SHA cannot.
- Configure **Dependabot** for `package-ecosystem: github-actions` to auto-bump pinned SHAs.
- Maintain an **action allowlist** at the org level (Settings → Actions → "Allow specified actions"). Block `*/*` by default.
- For high-risk actions (deploy, publish, sign), prefer **vendoring** the action into your own repo and pinning to that.

---

## Triggers — beware `pull_request_target` and `workflow_run`

- Default to `pull_request`. It runs in the **fork's untrusted context** with read-only token and **no secrets** — that's exactly what you want for PR validation.
- `pull_request_target` runs with **repo write token and secrets** in the context of the *base* repo while checking out *PR head code by default isn't the issue — explicitly checking out PR code is.* Rules:
  - Do not `actions/checkout` the PR head SHA in `pull_request_target` jobs that have secrets or write permissions. If you must, **separate** untrusted-code jobs (no secrets, read-only) from trusted jobs (secrets, no PR code).
  - Never run untrusted code (PR-supplied scripts, `npm install` of PR-modified deps, etc.) under `pull_request_target` with secrets in scope.
- `workflow_run` triggers run with elevated context too — same rules.
- For "comment to trigger" patterns (`issue_comment`, `pull_request_review`), gate on `author_association` (`OWNER`, `MEMBER`, `COLLABORATOR`) before doing anything privileged.
- Use `paths-ignore` / `paths` to keep workflows focused; don't run heavy CI on doc-only changes.

---

## Untrusted input — script injection

GitHub context expressions like `${{ github.event.pull_request.title }}` are **interpolated into shell scripts as raw text**. An attacker can put `$(rm -rf /)` in a PR title.

- **Never** interpolate `github.event.*` (or any user-controlled field) directly into `run:` scripts. The vulnerable list includes: `pull_request.title`, `pull_request.body`, `pull_request.head.ref`, `issue.title`, `issue.body`, `comment.body`, `review.body`, `commits.*.message`, `head_commit.message`, `*.author.name`, `*.author.email`, branch and tag names.
- Pass them through **environment variables**, then reference the env var (which the shell quotes safely):
  ```yaml
  - env:
      PR_TITLE: ${{ github.event.pull_request.title }}
    run: echo "$PR_TITLE"
  ```
- For input to `actions/github-script`, prefer the action's typed `inputs` over template interpolation in the script body.
- Treat `${{ ... }}` like SQL string concatenation: it's a code-injection primitive.

---

## Secrets

- Use **GitHub Environments** with required reviewers + deployment branch restrictions for any secret that grants production access.
- Reference secrets via `secrets.NAME`; never echo them, never persist them to disk, never pass them as positional CLI args (visible in `ps`).
- Mask custom values that are *derived* from secrets (`echo "::add-mask::$value"`).
- Do not pass secrets to third-party actions you haven't audited. Many actions don't need the secret at all (e.g. you can `env:` only on the step that actually uses it).
- For cloud auth, use **OIDC federation** (`id-token: write` + cloud trust policy) — no long-lived access keys in `secrets.*`. AWS, GCP, Azure, Vault all support this.
- Rotate any secret that has ever been printed in a log, even if masked.
- Forks **never receive secrets** by default — keep it that way. If a workflow seems to "need" secrets on PRs from forks, the design is wrong.

---

## Runner & job hardening

- Pin runner images: `runs-on: ubuntu-24.04`, not `ubuntu-latest`. `latest` rolls forward and breaks reproducibility.
- For untrusted code paths, prefer ephemeral self-hosted runners or GitHub-hosted runners. **Never** use long-lived self-hosted runners on public repos — a PR can execute arbitrary code on them.
- Self-hosted runners: ephemeral (`--ephemeral`), in an isolated network segment, with no access to other CI infra, and labels scoped per workload.
- `timeout-minutes` set on every job (default is 6 hours — too long for almost anything). Steps too if they can hang.
- `concurrency:` set to cancel superseded runs on the same ref where appropriate:
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```
  Do **not** cancel in-progress for deploy/release workflows on `main` — that can corrupt deploys.
- Restrict outbound network for sensitive jobs (e.g. `step-security/harden-runner` with `egress-policy: block`).
- `defaults.run.shell: bash` and `set -euo pipefail` in scripts. Default shell behavior swallows errors.

---

## Reusable workflows & composite actions

- Reusable workflows (`workflow_call`): pin callers to a SHA of the called workflow when consumed across repos.
- Composite actions: same pinning rules as third-party actions when consumed externally.
- Pass secrets explicitly via `secrets:` mapping, not `secrets: inherit`, unless the called workflow is fully trusted and you need everything.
- Inputs to reusable workflows: validate types; don't pass user-controlled values into shell without env-var indirection.

---

## Supply-chain integrity (build & release)

- **SBOM**: generate (Syft, `anchore/sbom-action`) and attach to releases.
- **Provenance**: emit SLSA provenance (`slsa-framework/slsa-github-generator`) for build artifacts; aim for SLSA Level 3.
- **Signing**: sign artifacts and container images with **cosign** keyless (OIDC). Verify signatures on consumption.
- **Dependency review**: `actions/dependency-review-action` on PRs to fail on new vulns / disallowed licenses.
- **Scanning**: CodeQL for code, Trivy/Grype for containers and IaC, secret scanning + push protection enabled at repo level.
- Publish to package registries via OIDC-trusted publishing (PyPI, npm provenance, Maven Central) where supported, not long-lived tokens.
- Tag releases on a protected branch with required reviewers + signed commits/tags.

---

## Branch & repo hygiene (call out if missing)

When reviewing, expect at the repo/org level:
- **Branch protection** on default and release branches: required reviews (≥ 1, ≥ 2 for prod-impacting), required status checks, dismiss stale reviews on push, require linear history, require signed commits, restrict force pushes and deletions.
- **CODEOWNERS** for sensitive paths (`.github/workflows/`, `terraform/`, `k8s/`, `Dockerfile*`, IAM policies).
- **Required reviews from Code Owners** enabled.
- **Tag protection** for release tags.
- **Actions settings**: fork PR workflows require approval; outside collaborators can't run workflows on first contribution; allowlist of permitted actions.
- **Secret scanning + push protection** on.
- **Dependabot security updates** on.
- **Two-factor authentication** required org-wide.

---

## Workflow style

- One responsibility per workflow file (CI, release, deploy-staging, deploy-prod). Don't bundle deploy into CI.
- Job names and step names are human-readable; `id:` only when referenced.
- `if:` conditions explicit and readable; avoid clever nested ternaries.
- Cache (`actions/cache`) keyed deterministically (lockfile hash) with a fallback `restore-keys`. Never cache secrets or build artifacts that contain secrets.
- Set `fetch-depth: 0` only when actually needed (release notes, blame); default `fetch-depth: 1` is faster and reduces blast radius.
- Use **matrix** with `fail-fast: false` for test fan-out; with `fail-fast: true` only when one failure makes others meaningless.

---

## Anti-patterns — reject on sight

- Missing top-level `permissions:` block
- `permissions: write-all` or any unjustified `*: write`
- Third-party action pinned to `@main`, `@master`, `@v1`, `@latest`, or any tag without a SHA
- `pull_request_target` that checks out PR head code with secrets/write token in scope
- `${{ github.event.* }}` interpolated directly into `run:` scripts
- `runs-on: ubuntu-latest` (or any `*-latest`)
- Missing `timeout-minutes`
- `secrets: inherit` to a third-party reusable workflow
- Long-lived cloud credentials in `secrets.*` when OIDC is available
- Self-hosted runners on public repos
- `echo ${{ secrets.X }}` (or any pattern that prints/leaks secrets)
- Workflows triggered by `issue_comment` / `pull_request_review` doing privileged work without `author_association` gate
- `run:` scripts without `set -euo pipefail` (or equivalent)
- Caching `node_modules`/build outputs that may contain secrets baked at build time
- Auto-merge / auto-approve workflows that bypass review
- Deploy workflows without an Environment + required reviewers

---

## Self-check (run mentally before declaring done)

- [ ] Top-level `permissions: { contents: read }`; writes scoped per job
- [ ] Every third-party action pinned by full commit SHA (with version comment)
- [ ] Dependabot configured for `github-actions` ecosystem
- [ ] No `pull_request_target` checking out PR code with secrets/write token in scope
- [ ] No raw `${{ github.event.* }}` (or other user-controlled field) in `run:` — passed via `env:` instead
- [ ] Cloud auth via OIDC, not long-lived keys
- [ ] Secrets scoped to the steps that need them; nothing logged
- [ ] Runner pinned to a specific OS version; `timeout-minutes` set; `concurrency` set appropriately
- [ ] `set -euo pipefail` in shell scripts
- [ ] Production deploys gated by Environment with required reviewers and branch restrictions
- [ ] SBOM + provenance + signing in release workflows
- [ ] Suggested `actionlint` + `zizmor` + Scorecard + `pinact` if not in CI
- [ ] Author-association / fork-approval gates on comment- and fork-triggered workflows

When reporting completion, explicitly list any rule you intentionally skipped and why.
