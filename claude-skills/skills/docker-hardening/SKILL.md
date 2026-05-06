---
name: docker-hardening
description: Use whenever creating, editing, or reviewing Dockerfiles, docker-compose.yml/yaml, .dockerignore, or any Docker-related build/runtime configuration. Enforces least-privilege and industry security best practices (CIS Docker Benchmark, NIST, OWASP container guidance). Trigger on file patterns Dockerfile*, *.dockerfile, docker-compose*.yml, docker-compose*.yaml, compose.yml, compose.yaml.
---

# Docker Hardening Skill

You are writing or reviewing Docker artifacts. Apply **principle of least privilege** at every layer. The rules below are non-negotiable defaults — deviate only when the user has an explicit, stated reason, and call out the deviation.

## How to use this skill

1. Before writing or editing, scan the existing file (if any) for current violations and note them.
2. Apply the rules in the relevant section below.
3. After writing, run the **Self-check** at the bottom and report any rule you knowingly skipped with a one-line justification.
4. If a linter/scanner is available locally (`hadolint`, `trivy`, `dockle`, `docker scout`), suggest running it. Do not silently skip findings.

---

## Dockerfile rules

### Base image
- **Pin by digest**, not just tag: `FROM image@sha256:...`. If pinning by digest is impractical, pin to a specific minor tag (e.g. `python:3.12.7-slim`), never `latest`, never bare major (`python:3`).
- Prefer **minimal bases** in this order: `distroless` → `-slim` → `alpine` → full. Justify any full base.
- Prefer official or verified-publisher images. Note provenance in a comment when using a less-common base.

### Multi-stage builds
- Use multi-stage builds for any compiled language or any image that needs build tooling. The final stage must contain **only runtime artifacts** — no compilers, package managers, build caches, or `.git`.
- Name stages (`AS build`, `AS runtime`) for clarity.

### User & privileges
- **Never run as root** in the final stage. Create a dedicated non-root user and group with a fixed, high UID/GID (e.g. `10001`):
  ```dockerfile
  RUN groupadd --system --gid 10001 app \
   && useradd  --system --uid 10001 --gid app --no-create-home --shell /sbin/nologin app
  USER 10001:10001
  ```
- Use **numeric** `USER` (not name) so Kubernetes `runAsNonRoot` checks pass.
- Do not use `sudo`, `setuid`/`setgid` binaries, or `--privileged`-requiring features.
- Drop capabilities at runtime; never add them in image metadata.

### Filesystem
- Make the image work with a **read-only root filesystem**. Write only to explicitly declared `VOLUME`s or `tmpfs` mounts.
- Set sane `WORKDIR` (never `/`). Ensure app directories are owned by the non-root user (`COPY --chown=app:app`).
- Add a `.dockerignore` covering at minimum: `.git`, `.env*`, `node_modules`, `__pycache__`, `*.pem`, `*.key`, `id_rsa*`, `.aws`, `.ssh`, `.terraform`, `coverage/`, build outputs, IDE folders.

### Package management
- Combine `apt-get update` + `install` in **one** `RUN`, with `--no-install-recommends`, and clean lists in the same layer:
  ```dockerfile
  RUN apt-get update \
   && apt-get install -y --no-install-recommends pkg1 pkg2 \
   && rm -rf /var/lib/apt/lists/*
  ```
- Pin package versions where feasible (`pkg=1.2.3-4`).
- For language package managers: use lockfiles and reproducible installs (`npm ci`, `pip install --require-hashes -r requirements.txt`, `bundle install --frozen`, `go mod download` with `GOFLAGS=-mod=readonly`).
- Remove package-manager caches (`pip --no-cache-dir`, `npm cache clean --force`, `apk --no-cache`).

### Secrets
- **Never** bake secrets into images. No secrets in `ENV`, `ARG`, `COPY`, or layer history.
- For build-time secrets, use BuildKit secrets: `RUN --mount=type=secret,id=npmrc ...`.
- For private registries, use `--mount=type=ssh` or short-lived tokens via BuildKit, never embedded credentials.
- Audit: assume `docker history` is public. If a secret would leak there, it's wrong.

### Network & ports
- `EXPOSE` only the ports the app actually serves. Prefer non-privileged ports (>1024) so the container can run as non-root.
- Do not bind to `0.0.0.0` in the Dockerfile config if a more specific bind is appropriate.

### Healthcheck & metadata
- Add a `HEALTHCHECK` for long-running services.
- Add OCI labels: `org.opencontainers.image.source`, `.revision`, `.version`, `.licenses`, `.title`, `.description`.

### Entrypoint
- Use **exec form** (`ENTRYPOINT ["/app/bin"]`), never shell form, so signals propagate (PID 1 handles SIGTERM correctly).
- If a shell wrapper is required, use `tini` or `dumb-init` as PID 1.
- Avoid `CMD ["sh", "-c", ...]` patterns that swallow signals.

### Layer hygiene
- Order instructions from least-frequently-changed to most-frequently-changed (base → system deps → language deps → app code) for cache efficiency.
- One logical concern per `RUN`. Avoid both giant monolithic `RUN`s and excessive layer fragmentation.

---

## docker-compose rules

### Service definition
- Pin image digests or specific tags; never `latest`.
- Set `user: "10001:10001"` (or matching UID/GID) on every service unless the image already enforces non-root.
- Set `read_only: true` and declare writable paths as `tmpfs:` or named volumes.
- Set `security_opt: ["no-new-privileges:true"]` on every service.
- Drop all capabilities, add only what is needed:
  ```yaml
  cap_drop: ["ALL"]
  cap_add: []   # add specific caps only with justification
  ```
- Never use `privileged: true`. Never mount the Docker socket (`/var/run/docker.sock`) unless the service's explicit job is Docker orchestration — and then call it out.
- Set `pids_limit`, `mem_limit`, and CPU limits to prevent resource exhaustion.
- Set `restart: unless-stopped` (or `on-failure`), not `always` for services that shouldn't auto-resurrect.

### Networking
- Define explicit networks; do not rely on the default bridge.
- Bind published ports to `127.0.0.1:` on host unless the service is genuinely public:
  ```yaml
  ports: ["127.0.0.1:8080:8080"]
  ```
- Use internal networks (`internal: true`) for backend-only services (databases, caches).

### Secrets & config
- Use `secrets:` (file- or swarm-backed), not `environment:` for sensitive values.
- Never commit `.env` files with real secrets. `.env.example` only.
- Mount config files **read-only**: `./config:/etc/app:ro`.

### Volumes
- Prefer named volumes over bind mounts in production compose files.
- Bind mounts must be `:ro` unless write access is genuinely required.
- Never bind-mount sensitive host paths (`/`, `/etc`, `/var/run/docker.sock`, `~/.ssh`, `~/.aws`).

### Healthchecks & dependencies
- Define `healthcheck:` for every long-running service.
- Use `depends_on:` with `condition: service_healthy` rather than bare `depends_on`.

---

## .dockerignore rules

Always include at minimum:
```
.git
.gitignore
.env
.env.*
!.env.example
*.pem
*.key
id_rsa*
.ssh
.aws
.gcloud
.azure
.terraform
.terraform.lock.hcl
node_modules
__pycache__
*.pyc
.venv
venv
.pytest_cache
.mypy_cache
coverage
.coverage
dist
build
*.log
.DS_Store
.idea
.vscode
README.md   # unless intentionally shipped
```

---

## Anti-patterns — reject on sight

- `FROM ubuntu:latest` / `FROM node` (unpinned)
- Missing `USER` directive (defaults to root)
- `USER root` in the final stage
- `chmod 777` anywhere
- `ADD http://...` (use `COPY` + verified download with checksum, or a build stage that fetches and verifies)
- `curl ... | sh` / `wget ... | bash` without checksum verification
- Secrets in `ENV` or `ARG` that persist into the final image
- `docker.sock` mounted into application containers
- `privileged: true`
- `network_mode: host` without explicit justification
- Running package managers (`apt`, `apk`, `pip`, `npm`) at container **runtime** (entrypoint)

---

## Self-check (run mentally before declaring done)

- [ ] Base image pinned (digest or specific minor tag, never `latest`)
- [ ] Multi-stage build if any build tooling is involved
- [ ] Non-root `USER` with numeric UID, set in final stage
- [ ] No secrets in image layers or compose env vars
- [ ] `.dockerignore` present and covers secrets/VCS/build artifacts
- [ ] Package installs pinned, `--no-install-recommends`, caches cleaned in same layer
- [ ] `ENTRYPOINT`/`CMD` in exec form
- [ ] Compose: `no-new-privileges`, `cap_drop: [ALL]`, `read_only: true`, resource limits, no socket mount, no `privileged`
- [ ] Healthcheck defined for long-running services
- [ ] Suggested running `hadolint` / `trivy` / `docker scout` if not already in CI

When reporting completion, explicitly list any rule you intentionally skipped and why.
