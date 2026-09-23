# Native agent contracts

Use these contracts after the Sol / Max bootstrap described in `SKILL.md`. The
orchestrator chooses each auxiliary model and reasoning effort; users never select or
confirm them.

For runtime evidence, fallback behavior, reviewer state checks, and maintainer
commands, use [operations.md](operations.md).

## Route and selection record

Before task tools, the orchestrator records the route and every initially selected
auxiliary:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit | full
risk: <concise task-specific rationale>
auxiliaries: none | <purpose — exact model — exact effort — reason>
~~~

If new evidence warrants a different model, effort, or route, emit a new declaration
that names the evidence and the change. Never silently substitute. Do not ask the
user to approve a routing choice.

Every auxiliary uses `fork_turns: none` so the orchestrator can set model and effort
explicitly and give it a clean, task-specific packet. Use only models and efforts
listed as available by the current native spawn tool.

The exact delivery modes are:

- `solo`: the orchestrator executes and verifies without an auxiliary.
- `delegate`: use one auxiliary. An implementer executes and the orchestrator verifies;
  a consultant advises or an explorer investigates, then the orchestrator executes
  and verifies.
- `audit`: the orchestrator executes and verifies; one fresh reviewer audits.
- `full`: use at most two auxiliaries. Compose implementer then reviewer; consultant
  or explorer then non-Astra implementer; or consultant or explorer then orchestrator
  execution then reviewer. Never combine a consultant and explorer. Two implementers
  may replace review only for genuinely independent ownership.

## Implementation packet

Use `agent_type: worker` for changes. Choose `model` and `reasoning_effort` from the
routing policy in `SKILL.md` and pass both explicitly:

~~~text
agent_type: worker
task_name: <short unique snake_case name>
fork_turns: none
model: <selected exact model id>
reasoning_effort: <selected supported effort>
~~~

The prompt must contain every section below:

~~~text
ROLE
Act as Sol Advisor's selected implementation worker. Execute the settled
specification, preserve every interface and constraint, and surface ambiguity rather
than widening scope.

OBJECTIVE
<Observable outcome and why it matters.>

FILES AND OWNERSHIP
You own only:
- <exact file or module>

You are not alone in the codebase. Other agents or the user may be editing
concurrently. Preserve their edits, do not revert unrelated work, and adapt to changes
already present. Do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, or behavior that must remain compatible.>

CONSTRAINTS
- <Repository conventions, safety boundaries, excluded scope, and settled decisions.>

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, or generated artifact>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence. A completion claim without evidence is
invalid.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file summary from the actual diff>
VERIFIED: <exact commands plus concrete output evidence>
JUDGMENT CALLS: <decisions the specification left open, or none>
GAPS: <unfinished work, ambiguity, or none>
~~~

The orchestrator must inspect the actual result and rerun verification itself. It
must not independently reimplement the same packet.

## Investigation packet

Use `agent_type: explorer` only for a specific, bounded codebase question. Give it an
exact question, relevant paths or symbols, and the evidence format required. Select
model and effort explicitly with `fork_turns: none`. Do not ask an explorer to make
edits or to perform a broad final review. An explorer counts as one auxiliary. Under
`delegate`, Sol acts on its findings. Under `full`, it may precede one non-Astra
implementer, or Sol may act on the findings before one fresh reviewer.
Do not add a consultant to either composition.

## Big-think consult packet

Use `agent_type: default` for an Astra consult only after the big-think gate in
`SKILL.md` is satisfied. Keep the consult bounded and read-only. Use `gpt-6-astra`
with the lowest effort that fits the decision, normally `high`:

~~~text
agent_type: default
task_name: big_think_consult_<unique_suffix>
fork_turns: none
model: gpt-6-astra
reasoning_effort: high | max | ultra
~~~

Prompt:

~~~text
ROLE
Act as a bounded strategic consultant. Do not edit files or execute the plan.

DECISION
<The exact high-leverage question.>

CONTEXT AND EVIDENCE
<The minimum complete facts, constraints, options, and conflicts.>

WHY ASTRA QUALIFIES
- Ambiguity: <specific evidence>
- Stakes or reversibility: <specific evidence>
- Cross-domain/adversarial need: <specific evidence>
- Downstream horizon: <what weeks or months of work could change>

RETURN
DECISION MEMO
RECOMMENDATION: <one clear recommendation>
KEY REASONS: <the decisive reasoning>
HIDDEN ASSUMPTIONS: <what the orchestrator should test>
FAILURE MODES: <strongest objections>
WHAT WOULD CHANGE THE ANSWER: <specific evidence>
~~~

The Astra consult counts as one auxiliary. After considering the memo, use one of
these declared compositions:

- `delegate`: the Sol / Max orchestrator implements and verifies.
- `full`: a selected non-Astra worker implements and Sol verifies, with no reviewer;
  or Sol implements and a selected reviewer audits.

The orchestrator owns the decision. Do not use Astra for bulk implementation, search,
summarization, routine review, or merely large tasks.

## Fresh review packet

Use `agent_type: default` with the selected review model and effort. The reviewer is
behaviorally read-only. The orchestrator must capture exact repository and artifact state before and after the review.

~~~text
agent_type: default
task_name: final_review_<unique_suffix>
fork_turns: none
model: <selected exact model id>
reasoning_effort: <selected supported effort>
~~~

Every reviewer and rereviewer gets a new unique task name. Never reuse a canonical
agent name for a fresh verdict.

Prompt:

~~~text
ROLE
Act as the fresh final reviewer. Remain strictly read-only: do not create, modify,
delete, format, or implement files, and do not broaden scope. Set
`GIT_OPTIONAL_LOCKS=0` and `-c core.fsmonitor=false` on every Git read, ignore all
submodules during worktree inspection, disable external diff and textconv filters,
and never run a mutating Git command.

STATED GOAL
<The user's requested outcome.>

ACCUMULATED CHANGE SET
<Exact allowed files plus complete working-tree diff, or explicit base/head revisions.>

INTERFACES AND CONSTRAINTS
- <Compatibility, repository rules, safety boundaries, and excluded scope.>

VERIFICATION EVIDENCE
- <command> -> <actual orchestrator output evidence>
- <artifact or diff inspection> -> <actual evidence>

REVIEW
Inspect the actual files and accumulated change set. Judge correctness, completeness,
regressions, scope discipline, interface preservation, test adequacy, and material
risk. Do not implement a finding.

SOL ADVISOR REVIEW
VERDICT: ship | fix-first | rethink
REASON: <decisive evidence-based reason>
FINDINGS: <precise file references and required fixes, or none>
RESIDUAL RISK: <most important remaining risk, or none>
~~~

Before review, capture a recursive content-and-metadata manifest for every writable
workspace root exposed to the reviewer, plus every writable external artifact/output
root, both the per-worktree Git directory and Git common directory, and every
symlink target it can reach. Do not narrow the snapshot to declared or changed files.
Include tracked, untracked, hidden, and ignored files plus content, identity,
ownership, timestamps, flags, extended attributes, and the complete relevant Git
diff. Capture the same evidence afterward and compare it before accepting the verdict.
If a writable root cannot be fully captured and hard read-only isolation is not
observed, do not use the review lane. Any detected mutation stops the lane and
invalidates the verdict. Any later implementation correction also invalidates the
verdict and requires fresh verification plus a new uniquely named reviewer when the
declared route still includes review.

## Rerouting and corrections

- A worker result that reveals more complexity or risk may justify a stronger model
  or higher effort. Record the new evidence and issue a new declaration first.
- A specification error belongs to the orchestrator. Correct the packet before
  retrying; do not blame the worker or automatically raise model capability.
- On `fix-first`, the orchestrator corrects the work in `audit`. In `full`, the
  implementer corrects an implementer→reviewer result; Sol corrects a
  consultant/explorer→Sol→reviewer result; and the relevant file owner corrects a
  two-implementer result. Re-verify before a fresh review.
- On `rethink`, revise the architecture and route. Do not report completion.
- If a selected model is unavailable, choose the nearest capable non-Astra option and
  record the substitution. Never use availability alone to cross the Astra gate.

Replacement workers and fresh rereviewers count as sequential attempts in the same
functional auxiliary lane, not additional route purposes. They require unique task
names and still consume usage.
