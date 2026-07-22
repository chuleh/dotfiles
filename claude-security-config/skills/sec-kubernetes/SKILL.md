---
name: sec-kubernetes
description: Use whenever creating, editing, or reviewing Kubernetes manifests, Helm charts, Kustomize overlays, or related cluster configuration. Enforces least-privilege, secure-by-default, and industry best practices (CIS Kubernetes Benchmark, NSA/CISA Kubernetes Hardening Guide, Pod Security Standards "restricted"). Trigger on file patterns *.yaml/*.yml under k8s/, kubernetes/, manifests/, deploy/, charts/, helm/, kustomize/, overlays/, base/; any file containing apiVersion: and kind:; Chart.yaml; kustomization.yaml; values*.yaml.
---

# Kubernetes Hardening Skill

You are writing or reviewing Kubernetes resources. Apply **principle of least privilege**, **defense in depth**, and **secure-by-default** at every layer. Target the Pod Security Standards **`restricted`** profile unless there is an explicit, stated reason to deviate.

## How to use this skill

1. Before editing, scan existing manifests for current violations and note them.
2. Apply the rules in the relevant sections.
3. After writing, run the **Self-check** at the bottom and report any rule you knowingly skipped with one-line justification.
4. Suggest running `kubeconform`, `kube-linter`, `kubesec`, `kube-score`, `polaris`, `trivy config`, and `checkov` if not already in CI.

---

## Workload security (Deployment / StatefulSet / DaemonSet / Job / CronJob)

### Pod-level `securityContext`
Every pod sets:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```

### Container-level `securityContext`
Every container sets:
```yaml
securityContext:
  allowPrivilegeEscalation: false
  privileged: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 10001
  capabilities:
    drop: ["ALL"]
    # add: []  # only with explicit justification, e.g. NET_BIND_SERVICE
```
- If the app needs to write, declare `emptyDir` or `tmpfs` volumes for the specific paths — do not relax `readOnlyRootFilesystem`.
- Never set `hostPID`, `hostIPC`, `hostNetwork`, or `hostUsers: true` without explicit justification.
- Never mount `hostPath`. If genuinely required (CNI, node agents), restrict to a specific path and `readOnly: true`.

### Images
- Pin by digest: `image: registry/app@sha256:...`. If unavoidable, pin to specific tag, never `:latest`.
- `imagePullPolicy: IfNotPresent` for digest-pinned, `Always` only when using mutable tags (and prefer not to).
- Pull from a trusted registry; use `imagePullSecrets` for private registries.
- See `sec-docker` skill for image content rules.

### Resources
- **Every container** sets both `requests` and `limits` for `cpu` and `memory`.
- Set `ephemeral-storage` requests/limits where workload writes scratch data.
- Use a `LimitRange` per namespace to enforce defaults.
- Use a `ResourceQuota` per namespace to cap aggregate consumption.

### Probes
- Define `livenessProbe`, `readinessProbe`, and (where startup is slow) `startupProbe`.
- Probes should hit a dedicated lightweight endpoint, not the same path as user traffic.
- Set sensible `initialDelaySeconds`, `periodSeconds`, `failureThreshold`.

### Disruption & scheduling
- `PodDisruptionBudget` for every multi-replica workload.
- `topologySpreadConstraints` or pod anti-affinity for HA workloads.
- `terminationGracePeriodSeconds` set explicitly; default 30s is often wrong for stateful apps.
- `priorityClassName` for system-critical workloads.

### ServiceAccount
- Every workload binds to a **dedicated** ServiceAccount — never the namespace `default`.
- `automountServiceAccountToken: false` unless the pod actually calls the API server.
- When token mounting is needed, use **projected, time-bound** tokens with explicit `audience`.
- For cloud access, use workload identity (IRSA / GKE Workload Identity / Azure Workload Identity), not static cloud credentials in Secrets.

---

## RBAC

- **No wildcards.** Avoid `verbs: ["*"]`, `resources: ["*"]`, `apiGroups: ["*"]`.
- Prefer `Role` + `RoleBinding` (namespace-scoped) over `ClusterRole` + `ClusterRoleBinding`.
- A `ClusterRoleBinding` to `cluster-admin` (or anything broad) requires explicit justification.
- Never bind roles to `system:authenticated` or `system:unauthenticated`.
- Service accounts get only the verbs they need on the specific resources they touch.
- Avoid `escalate`, `bind`, `impersonate`, `*/exec`, `*/portforward`, `secrets/*` permissions unless required.
- Audit who can `create pods` / `patch pods/ephemeralcontainers` — these are privilege-escalation paths.

---

## Network

### NetworkPolicy
- Every namespace has a **default-deny** ingress and egress NetworkPolicy:
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata: { name: default-deny, namespace: <ns> }
  spec:
    podSelector: {}
    policyTypes: ["Ingress", "Egress"]
  ```
- Workloads then add **explicit allow** policies for the traffic they actually need.
- Egress to external services restricted by namespace, label, or CIDR — not open `0.0.0.0/0`.
- DNS egress (`kube-dns`/`coredns` on UDP/TCP 53) explicitly allowed when needed.

### Service & Ingress
- Prefer `ClusterIP`; expose externally via Ingress/Gateway, not `NodePort`/`LoadBalancer` per service.
- TLS terminated at the edge; certificates from cert-manager / ACM / managed CA, not self-signed in prod.
- `Ingress`/`Gateway`: enforce HTTPS-only, modern TLS (≥ 1.2, prefer 1.3), strong ciphers, HSTS.
- WAF in front of public ingress where the platform supports it.
- mTLS between services (service mesh: Istio, Linkerd, Cilium) for production east-west traffic.

---

## Configuration & secrets

- **Secrets**:
  - Never commit plaintext `Secret` manifests. Use Sealed Secrets, SOPS, External Secrets Operator, or cloud-native (AWS Secrets Manager / GCP Secret Manager / Azure Key Vault) via CSI driver.
  - Encrypt secrets at rest (`EncryptionConfiguration` on the API server with a CMK / KMS provider). Verify this at the cluster level.
  - Mount as files on `tmpfs` rather than env vars where practical — env vars leak via `/proc`, crash dumps, and child processes.
  - Scope secrets per workload; do not share one Secret across unrelated apps.
- **ConfigMaps** carry config, never secrets — even "low-sensitivity" tokens.
- Mount config and secrets `readOnly: true`.
- Rotate secrets; prefer mechanisms that support automatic rotation.

---

## Pod Security & admission

- Namespaces enforce Pod Security Admission at the **`restricted`** level:
  ```yaml
  metadata:
    labels:
      pod-security.kubernetes.io/enforce: restricted
      pod-security.kubernetes.io/audit: restricted
      pod-security.kubernetes.io/warn: restricted
      pod-security.kubernetes.io/enforce-version: latest
  ```
- For policy beyond PSA, use **Kyverno** or **Gatekeeper/OPA** with policies for: image registry allowlist, required labels, required `securityContext`, blocked verbs, mandatory resource limits.
- Image signature verification (cosign / sigstore) for production clusters.

---

## Cluster-level expectations (call out if missing)

When reviewing cluster configuration (Terraform for EKS/GKE/AKS, kubeadm, etc.), expect:
- **Private control plane endpoint** or, if public, restricted by IP allowlist.
- **etcd encryption at rest** with a CMK.
- **Audit logging** enabled, shipped off-cluster, retained per compliance baseline.
- **Control plane logs** (api server, scheduler, controller-manager) shipped off-cluster.
- **Node OS**: minimal, auto-patched, immutable where possible (Bottlerocket, COS, Flatcar, AKS Mariner).
- **Worker nodes** in private subnets; no public IPs unless justified.
- **Cluster autoscaler** with bounded min/max.
- **Version**: within N-1 of the latest supported minor; auto-upgrades for patch versions.
- **Add-ons**: CNI with NetworkPolicy support (Cilium, Calico). CSI drivers up to date.
- **Metrics & logs**: Prometheus + Loki/CloudWatch/Stackdriver/Azure Monitor.
- See `sec-terraform` skill for IaC-side rules.

---

## Helm & Kustomize

### Helm
- Charts pin `apiVersion: v2`, declare `kubeVersion`, and pin dependency versions.
- `values.yaml` defaults are **production-safe** (see Variable Defaults policy in `sec-terraform`): non-root, drops caps, read-only FS, resource limits set, replicas ≥ 2 for HA workloads.
- Never template secrets into rendered manifests; use external secret stores.
- Sign and verify charts (provenance / cosign).
- Pin chart repository versions; never deploy from `latest`.

### Kustomize
- `kustomization.yaml` pins resource versions where possible.
- Overlays only override what's environment-specific; base must be deployable on its own.
- No secret generators committing plaintext literals.

---

## Logging & observability

- Containers log to **stdout/stderr** as structured JSON; no file logging in containers.
- Cluster ships logs via Fluent Bit / Vector / agent-of-choice to a tamper-resistant store.
- Metrics exposed on a dedicated port, scraped by Prometheus; sensitive metrics behind auth.
- Distributed tracing (OpenTelemetry) for request paths in prod.
- Alerts on: pods crashlooping, OOMKilled, image pull failures, RBAC denials spiking, NetworkPolicy drops spiking, certificate expiry.

---

## Anti-patterns — reject on sight

- Missing pod or container `securityContext`
- `runAsUser: 0` / `runAsNonRoot: false` / no `runAsNonRoot`
- `privileged: true`
- `allowPrivilegeEscalation: true` (or unset, which defaults true in some contexts)
- `readOnlyRootFilesystem: false` without justification
- Missing `capabilities.drop: ["ALL"]`
- `hostNetwork`, `hostPID`, `hostIPC`, or `hostPath` without justification
- `image: foo:latest` or unpinned tags
- Missing `resources.requests` / `resources.limits`
- Missing probes for long-running services
- Default ServiceAccount with `automountServiceAccountToken` left on
- `ClusterRoleBinding` to `cluster-admin`
- RBAC with `verbs: ["*"]` or `resources: ["*"]`
- No NetworkPolicy / no default-deny in namespace
- Plaintext `Secret` committed to git
- Secrets passed via env vars when files would do
- `NodePort` services exposed publicly
- Ingress without TLS / with TLS < 1.2
- Namespace without Pod Security Admission labels
- `emptyDir` for data that must survive a pod restart
- `kubectl apply -f` workflows without GitOps / review

---

## Self-check (run mentally before declaring done)

- [ ] Pod and container `securityContext` set; runs as non-root with numeric UID
- [ ] `readOnlyRootFilesystem: true`; writable paths via `emptyDir`/`tmpfs`
- [ ] `allowPrivilegeEscalation: false`, `privileged: false`, `capabilities.drop: ["ALL"]`
- [ ] `seccompProfile.type: RuntimeDefault`
- [ ] No host namespaces / no `hostPath` (or justified + `readOnly`)
- [ ] Image pinned by digest from trusted registry
- [ ] `resources.requests` and `limits` for cpu, memory (and ephemeral-storage where relevant)
- [ ] Liveness, readiness, and startup probes as appropriate
- [ ] Dedicated ServiceAccount; `automountServiceAccountToken` off unless needed
- [ ] RBAC: namespace-scoped where possible, no wildcards, no broad cluster bindings
- [ ] NetworkPolicy: default-deny in namespace + explicit allows for required flows
- [ ] Secrets sourced from external secret store; mounted read-only as files where practical
- [ ] Namespace labelled with Pod Security Admission `enforce: restricted`
- [ ] Ingress is HTTPS-only, modern TLS, with WAF in front when public
- [ ] PodDisruptionBudget + spread/affinity for multi-replica workloads
- [ ] Logs to stdout/stderr; metrics exposed for scraping
- [ ] Suggested `kubeconform` + `kube-linter` + `kubesec` + `trivy config` + `checkov` if not in CI

When reporting completion, explicitly list any rule you intentionally skipped and why.
