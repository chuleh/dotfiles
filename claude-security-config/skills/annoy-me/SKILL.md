---
name: annoy-me
description: A relentless interview that stress-tests a plan or design and writes the decisions down as docs (security/architecture ADRs and a glossary) while it goes. Use before building, when hardening a design, threat-modeling, or when the user says "annoy me", "grill me", "poke holes", or "stress-test this".
disable-model-invocation: true
---

# Annoy Me

Interview the user relentlessly about every aspect of this plan until you reach a shared understanding, and record the durable decisions as you go.

## The interview

Walk down each branch of the design tree, resolving dependencies between decisions one at a time. For each question, provide your recommended answer.

- Ask **one question at a time**. Wait for the answer before the next. Asking several at once is bewildering.
- If a question can be answered by reading the codebase, read the codebase instead of asking.
- Push on the weak points: trust boundaries, inputs that cross them, authn/authz, secret handling, blast radius, failure modes, and the assumptions the user has not stated. Surface tradeoffs rather than picking silently.
- Invent concrete edge-case scenarios and make the user be precise about the boundaries. "What happens when this token is leaked?" "Who can call this if the network policy is wrong?"

Stop when the design is sharp enough to build, not before.

## Write docs as you go

Capture decisions the moment they crystallise — do not batch them to the end.

### Glossary — `CONTEXT.md`

When a term is fuzzy, overloaded, or conflicts with existing usage, pin it down and record it in a root `CONTEXT.md`. Create the file lazily, on the first term resolved.

```md
# {Context Name}

{One or two sentences on what this context is.}

## Language

**Term**:
One or two sentences. Define what it IS, not what it does.
_Avoid_: synonyms you are deliberately not using
```

Rules: be opinionated (pick one word, list rejected synonyms under `_Avoid_`); keep definitions to one or two sentences; only include terms specific to this project, not general programming concepts. `CONTEXT.md` is a glossary, not a spec or scratchpad — no implementation details.

### Decisions — `docs/adr/NNNN-slug.md`

Offer an ADR **only** when all three are true:

1. **Hard to reverse** — changing your mind later is costly.
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **A real trade-off** — there were genuine alternatives and you picked one for reasons.

If any is missing, skip it. Number sequentially (scan `docs/adr/` for the highest and increment). Create `docs/adr/` lazily on the first ADR.

```md
# {Short title of the decision}

{1-3 sentences: the context, what was decided, and why.}
```

An ADR can be a single paragraph. The value is recording *that* a decision was made and *why*. Add `Status`, `Considered Options`, or `Consequences` sections only when they earn their place.

Security decisions that usually qualify: trust-boundary placement, authn/authz model, secret storage and rotation choices, encryption-at-rest options chosen, network exposure, deviations from a secure default and the justification, and constraints not visible in code (compliance, data residency).
