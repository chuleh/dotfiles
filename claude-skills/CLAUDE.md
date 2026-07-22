# General Instructions

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- Never use emojis.
- Never comment bash, python or terraform
- Don't use comments unless explictly old to.
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

# Claude Code Instructions - Cloud Security Engineering

## Security-First Principles

### CRITICAL - Never Compromise On These
- **NEVER commit secrets, API keys, credentials, or tokens** - Use secret managers (AWS Secrets Manager, HashiCorp Vault, GitHub Secrets) if none found prompt user
- **NEVER disable security features** without explicit user approval and documented justification
- **NEVER use privileged containers** (`privileged: true`) without explicit justification
- **NEVER run containers as root** - Always specify non-root user in Dockerfiles and K8s manifests
- **NEVER store sensitive data in ConfigMaps** - Use Secrets with encryption at rest
- **NEVER use `latest` tags** in production - Pin specific versions for reproducibility and security
- **NEVER skip input validation** - Validate and sanitize all external inputs

### Defense in Depth
- Apply principle of least privilege everywhere (IAM, RBAC, network policies)
- Implement multiple layers of security controls
- Assume breach mentality - design with compromise in mind
- Log security-relevant events for audit trails

## Stack-Specific Security Skills

Detailed, example-heavy security guidance lives in on-demand skills so it loads only when relevant (keeping this file lean). The non-negotiable guardrails above always apply regardless of whether a skill is loaded — when working in one of these stacks, also load the matching skill:

- `sec-kubernetes` — Pod Security Standards, SecurityContext, RBAC, secrets, resource limits. K8s manifests, Helm charts, kustomize.
- `sec-terraform` — remote state, module security, variable validation, provider pinning, sensitive outputs. `.tf` files.
- `sec-docker` — non-root, least-privilege, pinned base images, CIS Docker Benchmark. Dockerfiles, docker-compose.
- `sec-python` — input validation, dependency scanning, safe subprocess/SQL, crypto, error handling.
- `sec-ruby-rails` — Ruby on Rails security.
- `sec-github-actions` — secrets, SHA-pinned actions, OIDC, minimal permissions. `.github/workflows`.
- `sec-pre-commit` — set up commit-time secret scanning and IaC/code scanners (gitleaks, tfsec/checkov, bandit, hadolint). When the user wants to shift security scanning left.

---

## General Cloud Security

### IAM & Access Control
- Implement least privilege access
- Use role-based access, not user-based

### Network Security
- Use private subnets for resources when possible
- Implement VPC peering/transit gateway over public internet
- Use security groups as firewalls (deny by default)

### Encryption
- **Always encrypt data at rest** (Give user GCP options)
- **Always encrypt data in transit** (TLS 1.2+ only)
- Use KMS for key management, not custom solutions
- Warn if using a secret over 90 days old. If user ACKs move on

---

## Code Review Checklist

Before completing any task, verify:
- [ ] No secrets or credentials in code
- [ ] Input validation implemented
- [ ] Principle of least privilege applied
- [ ] Error handling doesn't expose sensitive info
- [ ] Dependencies are pinned and scanned
- [ ] Security context defined for K8s pods
- [ ] Encryption enabled for sensitive data
- [ ] Logging implemented for audit trail

---

## When to Ask Questions

**ALWAYS ask before:**
- Disabling any security feature
- Using privileged containers or root users
- Exposing services to the internet
- Making IAM/RBAC permission changes
- Modifying production resources
- Using experimental or unvetted tools
- Using secrets over 90 days old

**Provide options when:**
- Multiple secure approaches exist
- Trade-offs between security and functionality
- Compliance requirements might affect implementation
- Encrypting data at rest on GCP

---

## Communication Style

- Be explicit about security implications
- Explain WHY security measures are important
- Provide secure alternatives when rejecting approaches
- Reference security standards (CIS, NIST, OWASP)
- Flag potential security issues proactively

---

## Version Control

- **NEVER** work on master or main branch
- **NEVER** commit on master or main branch
- Never commit sensitive files (.env, credentials, keys)
- Use `.gitignore` for secrets and local configs
- Require PR reviews
- Use branch protection rules
