---
name: terraform-standards
description: Use whenever creating, editing, or reviewing Terraform code, modules, or related configuration. Enforces least-privilege, secure-by-default, and industry best practices (HashiCorp module structure, CIS cloud benchmarks, tfsec/checkov/trivy guidance). Trigger on file patterns *.tf, *.tfvars, *.tfvars.json, *.tf.json, terragrunt.hcl, .terraform.lock.hcl, modules/**, and any directory containing Terraform code.
---

# Terraform Standards Skill

You are writing or reviewing Terraform. Apply **principle of least privilege**, **immutable infrastructure**, and **secure-by-default** at every layer. Rules below are non-negotiable defaults — deviate only with explicit, stated reason and call it out.

## How to use this skill

1. Before editing, scan existing code for current violations and note them.
2. Apply the rules in the relevant sections.
3. After writing, run the **Self-check** at the bottom and report any rule you knowingly skipped with one-line justification.
4. Suggest running `terraform fmt`, `terraform validate`, `tflint`, `tfsec` (or `trivy config`), and `checkov` if not already in CI.

---

## Versioning & providers

- Every root module and reusable module declares `terraform { required_version = ">= 1.x.y" }` with a **specific minimum**, not unbounded.
- Every provider is pinned with a **pessimistic constraint** (`~> 5.40`) inside `required_providers`. Never omit version constraints.
- Commit `.terraform.lock.hcl`. Never `.gitignore` it.
- Pin module sources by **tag or commit SHA**, never bare `main`/`master`:
  ```hcl
  source = "git::https://github.com/org/repo.git//modules/x?ref=v1.4.2"
  ```
- Registry modules: pin `version = "~> 1.4"`.

## State

- **Remote state only** for anything beyond throwaway experiments. Never commit `terraform.tfstate`.
- Backend must have:
  - **Encryption at rest** (S3 SSE-KMS with CMK, GCS CMEK, Azure SSE with CMK).
  - **Versioning** enabled on the bucket/container.
  - **State locking** (DynamoDB for S3, native for GCS/AzureRM).
  - **Access logging** enabled on the state bucket.
  - **Public access fully blocked** on the state bucket.
- One state per environment per component. Never share state across environments.
- Use `terraform_remote_state` data source sparingly; prefer explicit data sources or SSM/Secrets Manager for cross-stack values.

## Module structure

Every reusable module has, at minimum:
```
modules/<name>/
  README.md          # purpose, usage example, inputs/outputs (terraform-docs)
  main.tf            # primary resources
  variables.tf       # all inputs with type, description, validation
  outputs.tf         # all outputs with description
  versions.tf        # required_version + required_providers
  CHANGELOG.md       # if versioned for consumers
```
- No `provider {}` blocks inside reusable modules — let the caller pass providers.
- Modules accept `tags`/`labels` as a variable and merge with module-internal defaults.
- Modules expose **all** sensitive resource attributes the caller might need; do not force re-querying via data sources.

## Variables

- Every variable has `type`, `description`, and (where applicable) `validation` blocks.
- Sensitive inputs marked `sensitive = true`.
- No defaults for **environment-specific** values (region, account, domain) — force the caller to be explicit.
- Use specific types (`map(object({...}))`) over `any`. `any` is a code smell.
- Validate enums with `validation { condition = contains([...], var.x) }`.

### Variable defaults policy

- Default **policy** variables (encryption, TLS version, retention, deletion protection, public-access flags, IMDSv2, logging, backup) to the **production-safe** value. Callers opt *out* with justification, never opt *in* to safety.
- Do **not** default **identity** variables (region, account, domain, VPC ID, subnet IDs, KMS key ARN, environment name). Force the caller to be explicit.
- Where a non-prod override is reasonable, use `validation {}` to prevent unsafe values in prod, e.g.:
  ```hcl
  validation {
    condition     = var.environment != "prod" || var.deletion_protection == true
    error_message = "deletion_protection must be true when environment = prod."
  }
  ```
- Document the default and *why it is the safe choice* in the variable's `description`.

## Outputs

- Every output has `description`.
- Outputs containing secrets, ARNs of secret resources, or connection strings are marked `sensitive = true`.
- Don't output raw secrets — output the **reference** (Secrets Manager ARN, SSM parameter name).

## Naming, tagging, structure

- `snake_case` for resource names, variables, outputs, locals.
- Resource local names describe **role**, not type: `aws_s3_bucket.artifacts`, not `aws_s3_bucket.bucket1`.
- Mandatory tags on every taggable resource: `Environment`, `Owner`, `CostCenter` (or `Team`), `ManagedBy = "terraform"`, `Repo`, `Component`. Enforce via a `local.common_tags` merged into every resource.
- Avoid `count` for resource toggling when `for_each` works — `for_each` is stable across reorderings.
- Never `count = var.create ? 1 : 0` to fake conditional modules at the resource level when a module-level toggle is cleaner.

## Secrets

- **Never** commit secrets to `.tfvars`, `.tf`, or state-readable outputs.
- Use Secrets Manager / SSM Parameter Store / Vault / GCP Secret Manager / Azure Key Vault.
- Pull secrets via `data` sources at apply time; do not pass plaintext through variables.
- Mark all secret-bearing variables and outputs `sensitive = true`.
- Be aware: **state contains everything**, including `sensitive` values in plaintext. State must be encrypted and access-restricted accordingly.

## IAM & access (cloud-agnostic principle, AWS-flavored examples)

- **Least privilege, always.** No `Action: "*"` on `Resource: "*"`. Scope both.
- No wildcard principals (`Principal: "*"`) without an explicit `Condition` restricting source.
- Prefer **roles + assume-role** over long-lived access keys. No IAM users for workloads.
- Service-to-service auth uses workload identity (IRSA on EKS, Workload Identity on GKE, Managed Identity on Azure), not static credentials.
- Inline policies for one-off, narrowly-scoped permissions; managed policies for reusable patterns. Avoid AWS-managed broad policies (`AdministratorAccess`, `PowerUserAccess`, `*FullAccess`).
- Every policy has a `Condition` where it makes sense (`aws:SourceVpce`, `aws:PrincipalOrgID`, `aws:SourceArn`, `StringEquals` on tags).

## Networking

- No `0.0.0.0/0` ingress on security groups except for genuinely public services (ALB/CDN), and even then only on 80/443.
- **Never** `0.0.0.0/0` to SSH (22), RDP (3389), database ports, or admin UIs. Use SSM Session Manager / IAP / Bastion + short-lived creds.
- Security group rules: one resource per rule (`aws_vpc_security_group_ingress_rule`), not inline `ingress` blocks — avoids drift.
- VPC endpoints for AWS services to keep traffic off the public internet (S3, KMS, Secrets Manager, ECR, STS at minimum).
- Flow logs enabled on every VPC. WAF on every public ALB/CloudFront.
- TLS only — no plaintext listeners except ACME challenge or explicit redirect-to-HTTPS.

## Storage

- **S3** (and equivalents):
  - `aws_s3_bucket_public_access_block` with all four flags `true` on every bucket.
  - SSE with KMS CMK (`aws_s3_bucket_server_side_encryption_configuration`).
  - Versioning enabled.
  - Bucket policy denies `aws:SecureTransport = false`.
  - Lifecycle rules for old versions / incomplete multipart uploads.
  - Access logging to a dedicated log bucket.
- **EBS / persistent disks**: encrypted with CMK, not the default key.
- **RDS / Cloud SQL / Azure SQL**:
  - Encryption at rest with CMK.
  - `publicly_accessible = false`.
  - In private subnets only.
  - Backups + PITR enabled, retention ≥ 7 days (≥ 30 for prod).
  - Deletion protection on prod.
  - Force TLS for connections.
  - Auto minor version upgrades enabled.
- **DynamoDB / Firestore**: PITR enabled, encryption with CMK.

## Compute

- EC2 / GCE / Azure VMs:
  - IMDSv2 required (`http_tokens = "required"` on AWS).
  - No public IPs unless genuinely public-facing.
  - Encrypted root + data volumes.
  - Instance profiles scoped to the workload, not broad.
- Containers (ECS/EKS/GKE/AKS): see `k8s-hardening` and `docker-hardening` skills for runtime concerns; Terraform side ensures private clusters, encrypted etcd, audit logging, restricted control-plane access.
- Lambda / Cloud Functions:
  - Minimal execution role.
  - Env vars encrypted with CMK; secrets fetched at runtime, not stored in env.
  - VPC-attached when accessing private resources.
  - Reserved concurrency where DoS-relevant.

## Logging & monitoring

- CloudTrail (or equivalent) enabled in **all regions**, multi-region, log file validation on, delivered to a dedicated, locked-down log archive account/bucket.
- Audit logs for the data plane (S3 access logs, RDS audit, K8s audit).
- Alarms on: root account usage, IAM policy changes, security group changes, CloudTrail disablement, console sign-in without MFA.
- Log retention meets compliance baseline (≥ 90 days hot, ≥ 1 year cold for prod typically).

## Encryption

- Use **customer-managed keys (CMK)** with rotation enabled, not cloud-default keys, for any data classified above public.
- Key policies follow least privilege; separate key admins from key users.
- TLS 1.2+ everywhere; TLS 1.3 where the service supports it.

## Code style

- `terraform fmt` clean. CI fails on unformatted code.
- One resource per file is overkill; group **logically related** resources per file (`network.tf`, `iam.tf`, `data.tf`).
- Locals for repeated expressions; don't inline the same `merge(var.tags, ...)` ten times.
- Avoid deeply nested `dynamic` blocks; if you need them, comment why.
- No `provisioner "local-exec"` / `remote-exec` unless genuinely no alternative — it breaks idempotency. Document why.
- No `null_resource` + `triggers` as a workaround for missing provider features without justification.

## Workflow

- Plan before apply. Review plans on PRs (Atlantis, Terraform Cloud, OpenTofu Cloud, env0, Spacelift, or CI artifact).
- Apply only from CI with a scoped role, not from laptops, for shared environments.
- `terraform import` over hand-editing state. Never `terraform state rm` without explaining why and confirming.
- Use workspaces sparingly; prefer **directory-per-environment** for clarity and blast-radius isolation.

---

## Anti-patterns — reject on sight

- Provider blocks without version constraints
- `.terraform.lock.hcl` in `.gitignore`
- Local state for anything shared
- `count = var.enabled ? 1 : 0` when a module toggle is cleaner
- `Action: "*"` + `Resource: "*"` IAM
- Wildcard principals without conditions
- `cidr_blocks = ["0.0.0.0/0"]` on 22/3389/DB ports
- Public S3 buckets / unblocked public access
- Unencrypted EBS, RDS, S3, DynamoDB
- Secrets in `.tfvars`, `default = "..."`, or `output` without `sensitive`
- Hardcoded account IDs, ARNs, or AMIs (use data sources)
- `provisioner "local-exec"` for what should be a provider resource
- `terraform apply -auto-approve` in interactive workflows
- Module sources pinned to `main`/`master`/branch names
- Outputting plaintext secrets

---

## Self-check (run mentally before declaring done)

- [ ] `required_version` and all providers pinned with version constraints
- [ ] Remote, encrypted, versioned, locked state with public access blocked
- [ ] Every variable: typed, described, validated where applicable; sensitive marked
- [ ] Every output: described; secrets marked sensitive or replaced with references
- [ ] Common tags applied to every taggable resource
- [ ] No wildcard IAM; conditions present where applicable
- [ ] No `0.0.0.0/0` to admin/DB ports
- [ ] All storage encrypted with CMK; S3 public access fully blocked; TLS enforced
- [ ] Databases private, backed up, deletion-protected (prod), TLS-only
- [ ] IMDSv2 required on instances; no unintended public IPs
- [ ] CloudTrail / audit logging enabled and protected
- [ ] No secrets in code, tfvars, or plaintext outputs
- [ ] `terraform fmt` clean; suggested `tflint` + `tfsec`/`trivy config` + `checkov` if not in CI
- [ ] Module sources and registry modules pinned by tag/SHA/version

When reporting completion, explicitly list any rule you intentionally skipped and why.
