---
name: orchestration
description: "Run a fresh Sol / Max architect that autonomously selects solo work or native agents with task-appropriate models and reasoning effort."
---

# Sol Advisor Orchestration

Use one fresh GPT-6 Sol agent at max reasoning as the architect and orchestrator.
The user supplies the goal and constraints; Sol owns route, model, effort,
decomposition, implementation or delegation, verification, and acceptance.

Never ask the user to confirm the orchestrator model, an auxiliary model, reasoning
effort, or route. Set them in native spawn calls and proceed. Ask the user only when a
genuine product or scope decision cannot be inferred and would materially change the
result.

## Bootstrap Sol / Max exactly once per invocation

Native subagents receive a `NEW_TASK` envelope. The marker
`SOL_ADVISOR_ORCHESTRATOR=1` distinguishes the orchestrator from its launcher only
when it is the exact first line after `Payload:` in that envelope. A quoted marker, a
later occurrence, or a marker inside the user's goal does not count.

If there is no `NEW_TASK` envelope whose payload begins with that exact first line,
act only as the launcher:

Use only the native collaboration `spawn_agent` operation for this bootstrap.
Never use `create_thread`, `fork_thread`, a sidebar-task launcher, or any external
task creation as a fallback. If native `spawn_agent` is unavailable or rejected,
stop and report a technical blocker without creating another task.

1. For every new skill invocation, generate a unique snake_case suffix and spawn one
   fresh native agent with the exact fields below. Never reuse a completed
   orchestrator or one created for an earlier invocation. The explicit spawn is the
   model selection; do not inspect or ask about the launcher's model.

   ~~~text
   agent_type: default
   task_name: sol_advisor_<unique_suffix>
   fork_turns: none
   model: gpt-6.1-sol
   reasoning_effort: max
   ~~~

2. The spawn prompt must begin with `SOL_ADVISOR_ORCHESTRATOR=1`, invoke
   `$sol-advisor:orchestration`, and carry the user's complete goal, constraints,
   relevant prior decisions, working directory, repository state already known, and
   required deliverables. Fresh context is intentional, so do not rely on inherited
   turns.
3. Wait for that agent. If new user input arrives while this exact invocation is
   active, forward it to this invocation's child; this is the only time to continue an
   existing orchestrator. Do not plan, implement, review, or duplicate its work in
   the launcher. Relay a real user-input blocker if one occurs; otherwise return its
   completed result and verification evidence.

If the `NEW_TASK` payload begins with that exact first line, do not spawn another
orchestrator. Continue with the operating contract below.

## Declare the route before task work

The bootstrap spawn is exempt from this declaration. Once inside the orchestrator,
emit one machine-auditable declaration before the first task tool call:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit | full
risk: <concise task-specific rationale>
auxiliaries: none | <purpose — exact model — exact effort — reason>
~~~

Choose the smallest route that improves the outcome. A later declaration may add or
upgrade an auxiliary only when newly observed complexity, risk, or failed evidence
justifies it. Record that evidence. Do not silently change the selected model or
effort.

## Select models and effort autonomously

Choose from models and efforts actually exposed by the native spawn tool. Use the
least expensive capable combination; increase capability or effort when ambiguity,
judgment, risk, or verification burden warrants it.

- **Luna:** mechanical investigation, narrow edits, repetitive work, and fully
  specified implementation. Start at low or medium; use high or max when the work is
  still bounded but precision or verification is demanding.
- **Terra:** (GPT-6 has no Terra; this role now runs `gpt-6-luna`.) Ordinary nontrivial coding, debugging, context-heavy implementation, and
  work with meaningful local judgment. Start at medium or high; use xhigh or max only
  for genuinely difficult contained work.
- **Sol:** difficult synthesis, architecture, cross-cutting decisions, and fresh
  review. Use high or max according to consequence and ambiguity.
- **Astra:** a bounded big-think consult only. Select Astra when the question is both
  unusually ambiguous and consequential, requires cross-domain synthesis or
  adversarial reasoning, and better framing could change weeks or months of work.
  State the qualifying signals in the route declaration. Task length, file count,
  bulk execution, or a desire for extra confidence does not qualify. Prefer a short
  consult that returns a decision memo. The consult counts as one auxiliary; Sol then
  implements itself or delegates implementation to Luna or Terra under the declared
  route. Use high first, max only when the decision warrants it, and ultra only for an
  exceptional case with an explicit reason.

Never fall upward into Astra merely because another model is unavailable. If a
selected auxiliary cannot be started, choose the nearest available non-Astra model
that still satisfies the task and record the reroute. Continue without requesting
model confirmation.

## Route delivery without duplication

- `solo`: the Sol / Max orchestrator plans, executes, verifies, and self-reviews.
- `delegate`: use exactly one auxiliary. An implementer executes a complete work
  packet and the orchestrator verifies it; a consultant returns a bounded decision
  memo or an explorer returns focused findings, after which the Sol orchestrator
  implements and verifies.
- `audit`: the orchestrator executes and verifies; one fresh selected reviewer audits
  the accumulated change set without writing.
- `full`: use at most two auxiliaries for broad or high-risk work. Valid compositions
  are implementer then reviewer; consultant or explorer then non-Astra implementer;
  or consultant or explorer, Sol implementation, then reviewer. Do not combine a
  consultant with an explorer. A second implementer replaces the reviewer only for
  genuinely independent ownership with no overlapping files.

Auxiliary work substitutes for orchestrator work; it does not duplicate it.
One auxiliary is the default maximum. Keep requirements, architecture, interface choices,
worker specifications, diff inspection, verification reruns, escalation decisions,
and final acceptance with the orchestrator.

The auxiliary limit counts functional lanes, not failed or correction attempts. A
replacement worker or fresh rereviewer occupies the same lane, runs sequentially with
a unique task name, and still consumes usage; it never authorizes another concurrent
purpose.

Before the first auxiliary spawn, read
[references/role-contracts.md](references/role-contracts.md). Use
[references/operations.md](references/operations.md) for exact spawn fields, runtime
evidence, review isolation, and maintainer procedures.

## Verify and accept

Treat every auxiliary report as a claim. Inspect the complete diff or artifact,
confirm changed-file scope, and rerun the narrowest meaningful checks in the
orchestrator. A reviewer returns exactly `ship`, `fix-first`, or `rethink` and never
implements its own finding. Any correction invalidates the prior verdict and requires
fresh verification; obtain another reviewer only when the declared route still
includes review.

Public spawn metadata is authoritative for model and effort. If it omits either
field, use the local inspector described in the operations reference only for the
omitted field. A conflict or unsafe reviewer mutation stops that affected lane; reroute
or correct it autonomously when safe rather than asking the user to choose a model.
