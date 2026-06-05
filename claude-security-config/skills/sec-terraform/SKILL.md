---
name: sec-terraform
description: Terraform security guidance — remote state encryption, module organization, input validation, provider pinning, and secrets handling for GCP/AWS/provider-agnostic IaC. Use when writing, reviewing, or refactoring .tf files, modules, variables, outputs, or provider/backend config.
---

# Terraform Security

## State Management
- **ALWAYS use remote state** with encryption (Terraform Cloud)
- **NEVER commit terraform.tfstate** files
- Enable state locking to prevent concurrent modifications

## Code Organization
- Use modules for reusable, secure components
- Implement input validation with variable constraints:
  ```hcl
  variable "environment" {
    type        = string
    description = "Environment name"
    validation {
      condition     = contains(["dev", "staging", "prod"], var.environment)
      error_message = "Environment must be dev, staging, or prod."
    }
  }
  ```

## Security Best Practices
- Prefer using latest providers **unless** provider version is pinned in the providers file
- Use `terraform plan` to review changes before apply
- Implement tagging strategy for resource tracking

## Secrets in Terraform
- **NEVER hardcode credentials** in .tf files
- Use data sources for secrets (GCP Secrets Manager)
- Mark sensitive outputs:
  ```hcl
  output "database_password" {
    value     = random_password.db_password.result
    sensitive = true
  }
  ```
