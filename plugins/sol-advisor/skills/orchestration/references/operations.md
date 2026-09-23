# Native operations

This reference defines the exact bootstrap, dynamic spawn, runtime-evidence, review,
and maintainer procedures for Sol Advisor v0.7.0.

## Sol / Max bootstrap

The launcher does not need to run on a particular model. It creates the actual
orchestrator with one fresh native spawn:

~~~text
agent_type: default
task_name: sol_advisor_<unique_suffix>
fork_turns: none
model: gpt-6-sol
reasoning_effort: max
~~~

Use only the native collaboration `spawn_agent` operation.
Never use `create_thread`, `fork_thread`, a sidebar-task launcher, or any external
task creation as a fallback. If native `spawn_agent` is unavailable or rejected,
stop and report a technical blocker without creating another task.

The native child receives a `NEW_TASK` envelope. The exact first line after its
`Payload:` label is the marker below, followed by a complete task packet:

~~~text
SOL_ADVISOR_ORCHESTRATOR=1
Use $sol-advisor:orchestration in orchestrator mode. Do not bootstrap another
orchestrator.

USER GOAL
<complete current request>

CONSTRAINTS AND PRIOR DECISIONS
<relevant conversation decisions, authorization boundaries, and required deliverables>

WORKSPACE
<working directory, repository, known dirty state, and relevant files>
~~~

A quoted marker, a later occurrence, or one embedded in user-supplied content does
not activate orchestrator mode. Do not scan the full envelope for the marker.

The explicit spawn fields enforce Sol / Max for this agent. Never ask the user to
confirm the launcher's model or the spawned selection. If the spawn itself is rejected
or its public metadata conflicts with the request, report a runtime/configuration
failure; a user model-choice prompt is not a remedy.

Every new skill invocation gets a new unique suffix and fresh orchestrator. Never
reuse a completed child or a child from an earlier invocation. The launcher waits for
the current orchestrator and does not duplicate its planning, implementation, or
review. If new user input changes or extends that same active invocation, use the
native collaboration follow-up or message operation for its exact child. Once that
invocation finishes, do not continue the child.

## Dynamic auxiliary spawns

Every auxiliary uses a fresh task-specific context and explicit routing fields:

~~~text
agent_type: worker | explorer | default
task_name: <short unique snake_case name>
fork_turns: none
model: <exact available model id>
reasoning_effort: <effort supported by that model>
~~~

Use `worker` for edits, `explorer` for specific codebase questions, and `default` for
bounded consultation or fresh review. The full prompt contracts are in
[role-contracts.md](role-contracts.md).

The model and effort choice must appear in the `SELECTIVE ROUTE` declaration. A later
change requires newly observed evidence and a new declaration. The user is not asked
to confirm a selection.

### Selection examples

These are calibration examples, not fixed lanes:

| Work | Typical model | Typical effort |
|---|---|---|
| File discovery, mechanical extraction, narrow deterministic edits | `gpt-6-luna` | `low` or `medium` |
| Bounded implementation with demanding verification | `gpt-6-luna` | `high` or `max` |
| Nontrivial implementation or debugging with local judgment | `gpt-6-luna` | `medium` or `high` |
| Difficult contained implementation with interacting concerns | `gpt-6-luna` | `xhigh` or `max` |
| Architecture, synthesis, or consequential fresh review | `gpt-6-sol` | `high` or `max` |
| Exceptional high-leverage, cross-domain decision memo | `gpt-6-astra` | `high`, rarely `max` or `ultra` |

Astra requires the big-think gate in `SKILL.md`. Do not use it for task volume,
routine coding, ordinary review, or availability fallback.

### Consult and investigation composition

Every consultant or explorer counts toward the auxiliary limit. Under `delegate`, it
returns a memo or findings and the Sol / Max orchestrator performs and verifies any
resulting implementation. Under `full`, choose one of two compositions: consultant or
explorer then non-Astra implementer with Sol verification, or consultant or explorer
then Sol implementation and a fresh reviewer. Do not combine a consultant and
explorer, and do not add both an implementer and reviewer after either one.

## Runtime routing evidence

Public spawn metadata is authoritative for role, model, and effort. A successful
spawn response that exposes the requested values is sufficient evidence; no separate
confirmation step is needed.

If public metadata omits model or effort, resolve the local inspector relative to the
installed skill and inspect only that exact native thread:

~~~sh
skill_dir=<directory-containing-SKILL.md>
runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
sh "$runtime_inspector" <native-subagent-thread-id>
~~~

For a disposable fixture or non-default session root:

~~~sh
sh "$runtime_inspector" --sessions-dir /absolute/path/to/sessions <native-subagent-thread-id>
~~~

The helper matches one exact rollout filename suffix and emits allowlisted routing
fields only. It refuses invalid IDs, zero or multiple matches, missing fields, or
conflicting model, effort, sandbox, permission, and working-directory values. Never
use it to discover arbitrary session content.

If public and local evidence both exist, they must agree. When an auxiliary is
misrouted, stop that lane. The orchestrator may choose another available non-Astra
model and record the reroute; it never asks the user to select a replacement.

## Reviewer isolation and state evidence

Dynamic model selection uses a standard fresh agent, so the reviewer contract is
behaviorally read-only unless the host exposes stronger isolation. Before spawning a
reviewer, record:

- `GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false status --short
  --ignore-submodules=all` and the complete relevant diff from
  `GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false diff --no-ext-diff
  --no-textconv --ignore-submodules=all`;
- a recursive SHA-256 and metadata manifest for every writable workspace root exposed
  to the reviewer, not merely the declared or changed-file scope;
- every writable external artifact/output root, per-worktree Git directory, and Git
  common directory the reviewer can reach, including tracked, untracked, hidden, and
  ignored artifacts;
- the exact allowed file set and each path's file type or missing state.

Use the packaged helper with every complete writable root. Directory roots are
recursively inventoried with content hashes, identity, ownership, mode, modification
and change times, platform file flags, and extended-attribute evidence, including
hidden, ignored, and `.git` artifacts:

~~~sh
skill_dir=<directory-containing-SKILL.md>
scope_snapshot="$skill_dir/../../scripts/snapshot-scope.sh"
sh "$scope_snapshot" --digest -- <writable-workspace-root> <external-artifact-root> <git-dir> <git-common-dir>
~~~

Record both the exact ordered root list and the compact digest so tool-output
truncation cannot hide a late manifest entry. Use the identical root list afterward;
the digest must match. The helper computes its digest only after a complete successful
scan, so an unreadable root fails instead of hashing partial or empty pipeline output.
Run it without `--digest` only to diagnose a mismatch, and do not let diagnostic
output replace the compact comparison.

Resolve both `GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false rev-parse
--path-format=absolute --git-dir` and
`GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false rev-parse --path-format=absolute
--git-common-dir`; linked worktrees commonly return distinct writable roots. Add each
distinct directory not
already contained in a snapshotted root. Explicitly add writable targets reached
through symlinks because the helper records a symlink rather than traversing it. If
any writable workspace, artifact, Git, or symlink-target root cannot be fully
snapshotted and hard read-only isolation is not observed, do not use or accept the
review lane; declare a safe route without it.

Set `GIT_OPTIONAL_LOCKS=0` and `-c core.fsmonitor=false` on every Git read performed
before, during, or after the review, including the two `rev-parse` calls above. Ignore
all submodules during worktree inspection. Disable external diff and textconv filters
when reading diffs. An unguarded status read may refresh the index through an optional
lock or execute an untrusted repository-configured filesystem-monitor hook, changing
Git metadata or arbitrary external state. Never run a mutating Git command in a
review lane.

After the reviewer returns, capture the same evidence and compare it. Accept the
verdict only when there was no mutation. If any file or artifact changed, invalidate
the review and stop that lane; do not hide or repair the mutation under its verdict.

Every reviewer or rereviewer uses a new unique `task_name`. Corrective workers and
rereviewers are sequential replacements in the same functional lane, so they do not
increase the route's auxiliary-purpose cap; they still consume usage and never run as
an undeclared extra purpose.

## Waiting and acceptance

Wait for the selected agent rather than recreating its task in the orchestrator. If
an auxiliary needs attention, resolve specification gaps in the orchestrator and send
a focused follow-up. After completion, inspect the actual files and rerun the
narrowest meaningful verification. Reports are evidence pointers, not acceptance.

For `audit` or `full`, a reviewer returns `ship`, `fix-first`, or `rethink`. Any code
or artifact correction invalidates the verdict. Re-verify and start a fresh reviewer
only if review remains part of the declared route.

## Legacy companion profiles

The v0.6.0 Luna, Terra, and Sol custom-agent templates and installer remain packaged
only so existing installations are understandable and recoverable. v0.7.0 dynamic
routing does not call those role types and does not require companion installation.
Existing user-owned copies may remain installed; they are inert unless explicitly
selected elsewhere.

## Maintainer verification

From the repository root, run:

~~~sh
sh plugins/sol-advisor/scripts/verify.sh
python3 /absolute/path/to/skill-creator/scripts/quick_validate.py plugins/sol-advisor/skills/orchestration
GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false diff --no-ext-diff --no-textconv --ignore-submodules=all --check HEAD --
GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false status --short --ignore-submodules=all
GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false diff --no-ext-diff --no-textconv --ignore-submodules=all --stat HEAD --
~~~

The repository verifier checks the v0.7.0 manifest, Sol / Max bootstrap, absence of
model-confirmation gates, dynamic spawn contracts, Astra big-think guard, safe runtime
inspection, recursive content snapshots, JSON/TOML validity for retained legacy
artifacts, and shell syntax.
