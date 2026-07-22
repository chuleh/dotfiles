# Claude Code Security Configuration

A shareable set of Claude Code customizations for cloud-security engineering. It layers four mechanisms — **instructions** (CLAUDE.md), **agents**, **skills**, and **slash commands** — plus **hooks** that announce when a security agent spawns and block dangerous/secret-leaking git commands. Once installed, these apply globally across every project.

The central design idea is **progressive disclosure**: keep the always-loaded footprint small, and load heavier, specialized content only when it is actually relevant. The sections below explain how each piece loads and when.

---

## Installation

Copy the framework into your personal Claude Code config directory (`~/.claude/`):

```sh
cp    CLAUDE.md            ~/.claude/CLAUDE.md     # or merge into your existing one
cp -R agents/*            ~/.claude/agents/
cp -R skills/*            ~/.claude/skills/
cp    commands/*.md       ~/.claude/commands/
cp -R hooks/*             ~/.claude/hooks/    # git-guardrails hook script
cp -R bin/*               ~/.claude/bin/      # commit-and-push wrapper (allowlisted)
```

Then merge `settings.example.json` into your own `~/.claude/settings.json` — do not overwrite the whole file, as your settings hold personal preferences:
- the two hooks (under `hooks.PreToolUse`) — summon announcer + git guardrail. See the hook section below.
- the `permissions.allow` entry `Bash(~/.claude/bin/commit-and-push.sh)` — allowlists the `commit-and-push` wrapper so `/commit-and-push` stages, commits, and pushes without per-step prompts.

Changes take effect in a **new** Claude Code session (config is read at startup). Verify with `/k8s-audit` or by listing skills.

> This repo intentionally contains **no** personal data: no `settings.json`/`settings.local.json`, no session transcripts, and no memory. See `.gitignore`.

---

## The loading model (start here)

Everything in this setup comes down to *what is in Claude's context, and when*. There are three loading behaviors:

| Mechanism | What is always in context | When the full body loads | Triggered by |
|---|---|---|---|
| **`CLAUDE.md`** | The entire file | Always (every session) | Loaded unconditionally at session start |
| **Agents** (`agents/`) | Only `name` + `description` | When the agent is **spawned** | Description relevance (Claude decides) or explicit invocation |
| **Skills** (`skills/`) | Only `name` + `description` | When the skill is **invoked** | Description relevance (Claude decides) or `/name` |
| **Slash commands** (`commands/`) | Nothing | When you type `/name` | You, explicitly |

Two things follow from this:

1. **Only CLAUDE.md is guaranteed loaded.** Agents and skills cost almost nothing until used (just a one-line description each). That is why heavy, stack-specific guidance lives in skills, not in CLAUDE.md.
2. **Triggering for agents and skills is heuristic.** Claude reads the `description` and decides whether to pull it in. There is no file-pattern or path binding. Reliable triggering depends on writing good descriptions — or forcing it with a slash command.

> Configuration is read at **session start**. Editing any file here does not hot-reload the current session; changes take effect in the next session (or after `/clear`).

---

## 1. CLAUDE.md — always-on instructions

`CLAUDE.md` is loaded into every session, in every project on this machine, and stays resident in context. It holds the non-negotiable, always-applicable rules:

- General engineering principles (think before coding, simplicity, surgical changes, goal-driven execution).
- The "Never Compromise" security guardrails (no committed secrets, no root containers, no `latest` tags, etc.).
- General cloud security, code-review checklist, "when to ask" rules, communication style, version-control rules.
- A short **pointer block** listing the stack-specific skills (see below) so Claude knows they exist and when to load them.

Because it is always loaded, it competes for context budget. It is deliberately kept lean — anything verbose or stack-specific was moved into skills.

- **File:** `CLAUDE.md`
- **Backup:** `CLAUDE.md.bak` (the original, pre-split version; restore with `cp CLAUDE.md.bak CLAUDE.md`)
- **Scope note:** Project-level `CLAUDE.md` files (in a repo's root or `.claude/`) stack *on top* of this global file when you work in that repo. More-specific instructions generally win on conflict.

---

## 2. Agents — isolated specialists

An **agent** (also called a subagent) runs as a **separate context window** with its own system prompt, its own tool allowlist, and its own model. It does a unit of work independently and returns a summary to the main conversation, keeping the main context clean.

Two custom security agents are defined:

| Agent | Purpose | Tools |
|---|---|---|
| `cloud-security-k8s` | Docker images, Kubernetes manifests, Helm charts, container hardening | all tools |
| `terraform-security` | Terraform / IaC security for GCP, AWS, provider-agnostic modules | Read, Write, Edit, Glob, Grep, Bash |

**Frontmatter that matters:**

```yaml
---
name: terraform-security
description: Secure infrastructure specialist for Terraform...
tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
---
```

- `model: inherit` means the agent uses **whatever model the session is running**. Opus session -> Opus agent; Sonnet session -> Sonnet agent. (Previously these were hardcoded to `opus`.)
- The `description` is what Claude matches against to decide whether to delegate. There is no file-pattern trigger — the tendency to fire "when editing K8s files" is a *consequence of the description wording*, not a rule.

**How an agent gets used:**
- **Auto-delegation** — Claude reads your request, sees it matches the description, and spawns the agent.
- **Explicit** — you say "use the cloud-security-k8s agent to…", or run a slash command (below).

- **Files:** `agents/cloud-security-k8s.md`, `agents/terraform-security.md`

---

## 3. Skills — on-demand reference

A **skill** loads its instructions **into the current conversation** when triggered — same context, same model, same tools. It is reference material injected inline, as opposed to an agent, which runs in isolation. Only each skill's `name` + `description` sit in context until it fires.

The verbose, example-heavy security guidance that used to live in CLAUDE.md lives in on-demand skills:

| Skill | Loads when working on | Notes |
|---|---|---|
| `sec-kubernetes` | K8s manifests, Helm charts, kustomize, Pod/RBAC specs | CIS/NSA hardening checklist + self-check |
| `sec-terraform` | `.tf` files, modules, backend/provider config | least-privilege, secure-by-default checklist |
| `sec-docker` | Dockerfiles, docker-compose, `.dockerignore` | CIS Docker Benchmark hardening |
| `sec-python` | Python code, `requirements.txt`, subprocess/SQL | |
| `sec-ruby-rails` | Ruby/Rails code | |
| `sec-github-actions` | `.github/workflows` YAML, actions, CODEOWNERS | supply-chain + least-privilege checklist |
| `sec-pre-commit` | setting up commit-time secret/IaC scanning | |
| `commit-and-push` | `/commit-and-push` — stage, commit, push via allowlisted `bin/` wrapper | not security; general workflow |

The `sec-` prefix groups them and avoids name collision with the `terraform-security` and `cloud-security-k8s` *agents* (agents and skills are separate namespaces, but the prefix keeps the human-facing names distinct).

**How a skill gets used:**
- **Auto** — Claude matches your work against the description and loads it.
- **Explicit** — you type `/sec-kubernetes`.

**Why guardrails stayed in CLAUDE.md, not skills:** skill loading is heuristic. Hard security rules ("never run as root") must always be in context, so they remain in always-on CLAUDE.md. Skills carry the *how-to detail*, which is fine to load only when relevant. This split is the deliberate "hybrid" design.

- **Files:** `skills/sec-*/SKILL.md`

### Agents vs. skills — the one-line distinction

- **Skill** = reference text loaded into *this* conversation. Cheap, inline, no isolation.
- **Agent** = a *separate* worker with its own context/tools/model that reports back. Use when you want isolation or a constrained toolset.

Both are selected the same way (description relevance or explicit invocation). Neither is file-pattern triggered.

---

## 4. Slash commands — forcing a spawn

Auto-delegation is reliable but never *guaranteed* — it is a heuristic. Slash commands are the deterministic trigger. A command is a markdown file whose body is a prompt injected when you type `/name`.

| Command | Effect |
|---|---|
| `/k8s-audit [target]` | Spawns the `cloud-security-k8s` agent to review the target |
| `/tf-audit [target]` | Spawns the `terraform-security` agent to review the target |

Each body explicitly instructs delegation (e.g. "Use the cloud-security-k8s subagent to review $ARGUMENTS… do not do the work yourself"). `$ARGUMENTS` is replaced with whatever you type after the command.

> Caveat: a command still routes through Claude to actually call the spawn tool — there is no model-bypassing binding. But the explicit wording makes it effectively deterministic.

- **Files:** `commands/k8s-audit.md`, `commands/tf-audit.md`

---

## 5. The "summoned" hook — spawn notifications

Hooks are commands the Claude Code harness runs at lifecycle events (the harness executes them, not Claude). A `PreToolUse` hook on the `Task` matcher prints a notification whenever one of the security agents spawns.

Configured in `settings.json`:

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Task",
      "hooks": [
        {
          "type": "command",
          "command": "jq -c 'if (.tool_input.subagent_type | IN(\"cloud-security-k8s\",\"terraform-security\")) then {systemMessage:\"\\(.tool_input.subagent_type) summoned\"} else empty end'"
        }
      ]
    }
  ]
}
```

How it works:
- The hook fires on **every** agent spawn (the `Task` matcher is tool-wide).
- The `jq` guard emits a `systemMessage` of `<agent> summoned` **only** when `subagent_type` is one of the two security agents.
- For any other agent (`Explore`, `general-purpose`, etc.) it produces `empty` — no output, silent.

So you see `cloud-security-k8s summoned` or `terraform-security summoned` and nothing else.

> The agent names are **hardcoded** in the `IN(...)` list. If you add or rename a security agent, update that list (see Maintenance).

- **Ships in:** `settings.example.json` — merge its `hooks.PreToolUse` block into your own `~/.claude/settings.json`.

---

## 6. The git-guardrails hook — block dangerous commands

A second `PreToolUse` hook, on the `Bash` matcher, runs `hooks/block-dangerous-git.sh` before any Bash command executes. It enforces the version-control rules from `CLAUDE.md` as a hard control instead of prose Claude can overlook. When it blocks, the script exits `2` and writes a `BLOCKED:` reason to stderr, which Claude sees.


What it blocks:
- **Destructive git ops** — `git push` (incl. `--force`), `reset --hard`, `clean -f`/`-fd`, `branch -D`, `checkout .`, `restore .`.
- **Commits to `main`/`master`** — checks the current branch on `git commit` and blocks it (your CLAUDE.md forbids working on main/master).
- **Secret-bearing files** — blocks `git add`/`git commit` of likely secrets matched by filename (`.env` and variants except `.env.example`/`.sample`/`.template`/`.dist`/`.defaults`; `*.pem`/`*.key`/`*.p12`/`*.pfx`/`*.keystore`/`*.jks`; `id_rsa`/`id_dsa`/`id_ecdsa`/`id_ed25519`; `*credentials*`, `client_secret*`, `*service-account*.json`). On `git commit` it also scans the staged file list (`git diff --cached --name-only`), catching secrets staged via `git add .`.

It is name-based, not content-based — it complements, not replaces, a real secret scanner (gitleaks/trufflehog) in pre-commit/CI.

- **Ships in:** `hooks/block-dangerous-git.sh` (copy to `~/.claude/hooks/`) plus the `Bash` matcher in `settings.example.json` (merge into your own `~/.claude/settings.json`).
- **Customize:** edit `DANGEROUS_PATTERNS` or the `secret_match` regexes in the script.
- **Test:** `echo '{"tool_input":{"command":"git push"}}' | ~/.claude/hooks/block-dangerous-git.sh` should exit `2`.

---

## Directory map (this repo)

```
.
├── CLAUDE.md                      # always-on instructions (lean) -> ~/.claude/CLAUDE.md
├── README.md                      # this file
├── settings.example.json         # summoned + git-guardrails hooks to merge into ~/.claude/settings.json
├── .gitignore                    # excludes all personal/runtime state
├── hooks/
│   └── block-dangerous-git.sh    # PreToolUse(Bash) guardrail -> ~/.claude/hooks/
├── bin/
│   └── commit-and-push.sh        # allowlisted stage+commit+push wrapper -> ~/.claude/bin/
├── agents/
│   ├── cloud-security-k8s.md      # K8s/container agent  (model: inherit)
│   └── terraform-security.md      # Terraform agent      (model: inherit)
├── skills/
│   ├── sec-kubernetes/SKILL.md
│   ├── sec-terraform/SKILL.md
│   ├── sec-docker/SKILL.md
│   ├── sec-python/SKILL.md
│   ├── sec-ruby-rails/SKILL.md
│   ├── sec-github-actions/SKILL.md
│   ├── sec-pre-commit/SKILL.md    # set up commit-time secret/IaC scanning
│   ├── commit-and-push/SKILL.md   # /commit-and-push — uses bin/ wrapper
│   └── annoy-me/SKILL.md          # /annoy-me — relentless design grilling + ADRs/glossary
└── commands/
    ├── k8s-audit.md               # /k8s-audit -> cloud-security-k8s
    └── tf-audit.md                # /tf-audit  -> terraform-security
```

Everything here installs under `~/.claude/`. Personal files (`settings.json`, `settings.local.json`, `projects/`, backups, runtime state) are deliberately excluded — see `.gitignore`.

---

## Maintenance

**Add a new skill:** create `skills/<name>/SKILL.md` with `name` + `description` frontmatter and the body. Write a trigger-rich description so it auto-loads. Add a pointer line in `CLAUDE.md`'s skills block if it is security-relevant.

**Add a new agent:** create `agents/<name>.md` with `name`, `description`, optional `tools`, and `model: inherit`. If you want it announced on spawn, add its name to the hook's `IN(...)` list in `settings.example.json` (and your own `~/.claude/settings.json`). Optionally add a `/`-command in `commands/` to force-spawn it.

**Rename/remove a security agent:** update the `IN(...)` allowlist in `settings.example.json` and your own `~/.claude/settings.json`, plus any matching slash command.

**Change the always-on rules:** edit `CLAUDE.md`. Keep it lean — push verbose, stack-specific detail into a skill instead.

**Tune the git guardrails:** edit `hooks/block-dangerous-git.sh` — add/remove entries in `DANGEROUS_PATTERNS`, or adjust the `secret_match` regexes for your secret-file naming. Re-test with the one-liner in the git-guardrails hook section.

**Verify a change:** configuration is read at session start, so changes apply in a **fresh session** (or after `/clear`). To confirm a hook fires, temporarily prefix its command with a sentinel write (e.g. `tee -a /tmp/x.log | …`), trigger it, inspect the file, then revert.
