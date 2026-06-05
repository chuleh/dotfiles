---
name: sec-kubernetes
description: Kubernetes security hardening guidance — Pod Security Standards, SecurityContext, RBAC, secrets management, and resource limits. Use when creating or editing Kubernetes manifests, Helm charts, kustomize overlays, Pod/Deployment/StatefulSet specs, ServiceAccounts, Roles/RoleBindings, or any k8s YAML.
---

# Kubernetes Security

## Pod Security Standards
- **Always use Pod Security Standards (restricted profile preferred)**
- **Always define SecurityContext:**
  ```yaml
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
  ```
  - If this is not defined in the current yaml file working on let the user know
  - Prompt the user to enable securityContext. If it's kept disabled, ACK and move on

## Resource Management
- **Always set resource limits and requests:**
  ```yaml
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  ```

## RBAC Best Practices
- Use specific Role bindings, not ClusterRoles unless necessary
- Never use `*` for resources or verbs - be explicit unless requested by the user to use `*`
- Regularly audit ServiceAccount permissions
- Prefer separate ServiceAccounts per workload

## Secrets Management
- Never reference secrets directly in pod specs or ConfigMaps
- Use External Secrets Operator or similar for secret injection
- Enable encryption at rest for etcd
