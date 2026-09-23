#!/bin/sh
# Repository-local verification for Sol Advisor's dynamic Sol / Max orchestration.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
operations=$plugin_dir/skills/orchestration/references/operations.md
ui=$plugin_dir/skills/orchestration/agents/openai.yaml
readme=$repo_dir/README.md
marketplace=$repo_dir/.agents/plugins/marketplace.json
runtime_inspector=$script_dir/inspect-agent-runtime.sh
scope_snapshot=$script_dir/snapshot-scope.sh
legacy_installer=$script_dir/install-agents.sh
legacy_templates=$plugin_dir/agents

tmp_base=/tmp
tmp_env=$(printenv TMPDIR 2>/dev/null || true)
if [ -n "$tmp_env" ]; then tmp_base=$tmp_env; fi
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"

luna_file=sol-advisor-luna-implementer.toml
terra_file=sol-advisor-terra-implementer.toml
sol_file=sol-advisor-sol-reviewer.toml
legacy_luna_sha256=fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb
legacy_terra_sha256=4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca
legacy_luna_v050_sha256=5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853
legacy_terra_v050_sha256=dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce

snapshot_legacy_target() {
  sh "$scope_snapshot" -- "$1"
}

write_legacy_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$luna_file" <<'LEGACY_LUNA'
name = "sol_advisor_luna_implementer"
description = "Sol Advisor's routine implementation lane for bounded, fully specified work."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's routine implementation worker. Execute the supplied five-part
implementation specification exactly when it is bounded and largely determined by
the contract. Preserve stated interfaces and constraints, make only the files you
own, and adapt to concurrent edits instead of reverting work you do not own.

Surface material ambiguity, missing acceptance criteria, scope conflicts, or failed
verification rather than redesigning the architecture. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the required routine lane.
"""
LEGACY_LUNA
  cat > "$target/$terra_file" <<'LEGACY_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's complex implementation lane for context-heavy or higher-risk work."
model = "gpt-5.6-terra"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's complex implementation worker. Resolve difficult implementation
details within the settled architecture, including context-heavy, higher-risk, or
wider-blast-radius work. Preserve every stated interface and constraint, stay within
the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than changing the architecture without direction. Run the requested checks and report
actual evidence. Do not silently substitute a different role, model, or reasoning
level; this installed custom-agent profile is the required complex lane.
"""
LEGACY_TERRA
  cp "$legacy_templates/$sol_file" "$target/$sol_file"
  [ "$(shasum -a 256 "$target/$luna_file" | awk '{print $1}')" = "$legacy_luna_sha256" ] || fail "legacy Luna fixture digest drifted"
  [ "$(shasum -a 256 "$target/$terra_file" | awk '{print $1}')" = "$legacy_terra_sha256" ] || fail "legacy Terra fixture digest drifted"
}

write_v050_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$luna_file" <<'V050_LUNA'
name = "sol_advisor_luna_implementer"
description = "Sol Advisor's default routine implementation lane for bounded, fully specified work."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's default routine implementation worker. Execute the supplied
five-part implementation specification when the work is bounded and largely
determined by the contract. Preserve every stated interface and constraint, stay
within the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface material ambiguity, scope conflicts, or verification failures
rather than redesigning the architecture. Run the requested checks and report actual
evidence. If one corrected attempt shows that the work is judgment-heavy, high-risk,
or misclassified as routine, stop and return that signal so the parent can escalate
it to Terra / High. Do not silently substitute a different role, model, or reasoning
level; this installed custom-agent profile is the required routine lane.
"""
V050_LUNA
  cat > "$target/$terra_file" <<'V050_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's explicit high-complexity escalation lane for judgment-heavy or high-risk work."
model = "gpt-5.6-terra"
model_reasoning_effort = "high"

developer_instructions = """
You are Sol Advisor's explicit high-complexity escalation worker. Execute the
supplied five-part implementation specification within the settled architecture when
the parent identifies judgment-heavy, high-risk, or wider-blast-radius work, or when
one corrected Luna attempt shows that routine routing was a misclassification.
Preserve every stated interface and constraint, stay within the owned file set, and
document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than redesigning the architecture without direction. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the required escalation lane.
"""
V050_TERRA
  cp "$legacy_templates/$sol_file" "$target/$sol_file"
  [ "$(shasum -a 256 "$target/$luna_file" | awk '{print $1}')" = "$legacy_luna_v050_sha256" ] || fail "v0.5.0 Luna fixture digest drifted"
  [ "$(shasum -a 256 "$target/$terra_file" | awk '{print $1}')" = "$legacy_terra_v050_sha256" ] || fail "v0.5.0 Terra fixture digest drifted"
}

for required in "$manifest" "$skill" "$contracts" "$operations" "$ui" "$readme" "$marketplace" "$runtime_inspector" "$scope_snapshot" "$legacy_installer"; do
  test -f "$required" || fail "required file missing: $required"
done
pass "required files present"

jq empty "$manifest"
jq empty "$marketplace"
[ "$(jq -r '.version' "$manifest")" = 0.7.1 ] || fail "manifest version is not 0.7.1"
grep -Fq 'fresh GPT-6 Sol / Max orchestrator' "$manifest" || fail "manifest omits Sol / Max bootstrap"
grep -Fq 'without asking the user to confirm a model, effort, or lane' "$manifest" || fail "manifest omits no-confirmation behavior"
grep -Fq 'chooses each auxiliary model and reasoning effort' "$manifest" || fail "manifest omits dynamic selection"
grep -Fq 'Astra only for a bounded big-think consult' "$manifest" || fail "manifest omits Astra guard"
pass "manifest and marketplace JSON"

for document in "$skill" "$operations"; do
  grep -Fq 'agent_type: default' "$document" || fail "Sol bootstrap agent type missing from $document"
  grep -Fq 'task_name: sol_advisor_<unique_suffix>' "$document" || fail "unique Sol bootstrap task name missing from $document"
  grep -Fq 'fork_turns: none' "$document" || fail "fresh bootstrap context missing from $document"
  grep -Fq 'model: gpt-6-sol' "$document" || fail "Sol bootstrap model missing from $document"
  grep -Fq 'reasoning_effort: max' "$document" || fail "Sol bootstrap effort missing from $document"
  grep -Fq 'SOL_ADVISOR_ORCHESTRATOR=1' "$document" || fail "bootstrap recursion guard missing from $document"
done
grep -Fq 'exact first line after `Payload:`' "$skill" || fail "skill does not anchor to the NEW_TASK payload"
grep -Fq 'there is no `NEW_TASK` envelope whose payload begins' "$skill" || fail "launcher guard ignores native envelope semantics"
grep -Fq 'A quoted marker' "$skill" || fail "skill does not reject quoted markers"
grep -Fq 'later occurrence' "$skill" || fail "skill does not reject later markers"
grep -Fq 'exact first line after its' "$operations" || fail "operations do not anchor the NEW_TASK payload"
grep -Fq 'do not inspect or ask about the launcher' "$skill" || fail "skill may inspect launcher model"
grep -Fq 'Never ask the user to confirm the orchestrator model' "$skill" || fail "skill omits no-confirmation rule"
grep -Fq 'Do not plan, implement, review, or duplicate its work' "$skill" || fail "launcher may duplicate orchestrator work"
grep -Fq 'For every new skill invocation' "$skill" || fail "skill does not require a fresh orchestrator per invocation"
grep -Fq 'Never reuse a completed' "$skill" || fail "skill may reuse a completed orchestrator"
grep -Fq 'this is the only time to continue an' "$skill" || fail "active-invocation follow-up boundary is missing"
if grep -Eq '^[[:space:]]*task_name: sol_advisor$' "$skill" "$operations"; then
  fail "bootstrap still uses a collision-prone fixed task name"
fi
for document in "$skill" "$operations"; do
  grep -Fq 'Never use `create_thread`, `fork_thread`' "$document" || fail "launcher fallback guard missing from $document"
  grep -Fq 'If native `spawn_agent` is unavailable or rejected' "$document" || fail "native spawn failure behavior missing from $document"
  grep -Fq 'without creating another task' "$document" || fail "launcher may create a user-owned task on bootstrap failure"
done
pass "fresh Sol / Max bootstrap and no-confirmation contract"

for old_phrase in \
  '## Confirm the primary session' \
  'ask the user to confirm Sol / High' \
  'stop until confirmed' \
  'tell the user to select Sol / High' \
  'The primary session must be Sol / High'; do
  if grep -Fq "$old_phrase" "$skill" "$contracts" "$operations" "$readme" "$manifest" "$ui"; then
    fail "obsolete model-confirmation gate remains: $old_phrase"
  fi
done
pass "obsolete model-confirmation gates absent"

grep -Fq 'SELECTIVE ROUTE' "$skill" || fail "skill omits route declaration"
grep -Fq 'mode: solo | delegate | audit | full' "$skill" || fail "skill omits exact route modes"
grep -Fq 'auxiliaries: none | <purpose — exact model — exact effort — reason>' "$skill" || fail "route does not record selection"
for mode in solo delegate audit full; do
  grep -Fq "\`$mode\`" "$skill" || fail "skill omits $mode"
  grep -Fq "\`$mode\`" "$contracts" || fail "contracts omit $mode"
done
grep -Fq 'One auxiliary is the default maximum' "$skill" || fail "skill omits auxiliary limit"
grep -Fq 'Auxiliary work substitutes for orchestrator work' "$skill" || fail "skill permits duplicate auxiliary work"
grep -Fq 'newly observed complexity, risk, or failed evidence' "$skill" || fail "skill omits evidence-gated rerouting"
pass "selective route contract"

for model in Luna Terra Sol Astra; do
  grep -Fq "**$model:**" "$skill" || fail "skill omits $model routing guidance"
done
grep -Fq 'least expensive capable combination' "$skill" || fail "skill omits efficiency rule"
grep -Fq 'Task length, file count' "$skill" || fail "skill lets task volume trigger Astra"
grep -Fq 'Never fall upward into Astra' "$skill" || fail "skill allows Astra availability fallback"
grep -Fq 'WHY ASTRA QUALIFIES' "$contracts" || fail "contracts omit Astra gate evidence"
grep -Fq 'Do not use Astra for bulk implementation' "$contracts" || fail "contracts permit routine Astra use"
grep -Fq 'The Astra consult counts as one auxiliary' "$contracts" || fail "contracts omit consult accounting"
grep -Fq '`delegate`: the Sol / Max orchestrator implements and verifies' "$contracts" || fail "delegate consult has no executor"
grep -Fq '`full`: a selected non-Astra worker implements and Sol verifies' "$contracts" || fail "full consult has no non-Astra execution path"
grep -Fq 'do not add both an implementer and reviewer after either one' "$operations" || fail "operations permits an unbounded consult chain"
pass "autonomous model/effort routing and Astra big-think gate"

grep -Fq 'agent_type: worker' "$contracts" || fail "implementation spawn missing"
grep -Fq 'agent_type: explorer' "$contracts" || fail "investigation spawn missing"
grep -Fq 'An explorer counts as one auxiliary' "$contracts" || fail "explorer accounting is undefined"
grep -Fq 'Do not add a consultant to either composition' "$contracts" || fail "explorer composition permits an extra consultant"
grep -Fq 'model: <selected exact model id>' "$contracts" || fail "dynamic model field missing"
grep -Fq 'reasoning_effort: <selected supported effort>' "$contracts" || fail "dynamic effort field missing"
for section in 'OBJECTIVE' 'FILES AND OWNERSHIP' 'INTERFACES' 'CONSTRAINTS' 'VERIFICATION' 'IMPLEMENTATION REPORT'; do
  grep -Fq "$section" "$contracts" || fail "worker contract omits $section"
done
grep -Fq 'Remain strictly read-only' "$contracts" || fail "reviewer lacks read-only instruction"
grep -Fq 'capture exact repository and artifact state before and after' "$contracts" || fail "reviewer lacks state guard"
grep -Fq 'every writable' "$contracts" || fail "reviewer snapshot is not rooted at every writable workspace"
grep -Fq 'Do not narrow the' "$contracts" || fail "reviewer may snapshot only declared files"
grep -Fq 'tracked, untracked, hidden, and ignored' "$contracts" || fail "reviewer scope omits non-Git artifacts"
grep -Fq 'Git common directory' "$contracts" || fail "reviewer snapshot omits linked-worktree common metadata"
grep -Fq 'symlink target' "$contracts" || fail "reviewer snapshot omits writable symlink targets"
for document in "$contracts" "$operations"; do
  grep -Fq 'GIT_OPTIONAL_LOCKS=0' "$document" || fail "lock-free Git read contract missing from $document"
  grep -Fq 'core.fsmonitor=false' "$document" || fail "fsmonitor-disabled Git read contract missing from $document"
done
grep -Fq 'diff --no-ext-diff' "$operations" || fail "review diff may invoke external filters"
grep -Fq -- '--no-textconv' "$operations" || fail "review diff may invoke textconv filters"
grep -Fq -- '--ignore-submodules=all' "$operations" || fail "review Git reads may traverse submodules"
if grep -Eq '(^|`|[[:space:]])git (status|diff|rev-parse)' "$operations"; then
  fail "operations contains an unguarded Git read example"
fi
if awk '/GIT_OPTIONAL_LOCKS=0 git/ && !/-c core[.]fsmonitor=false/ { found=1 } END { exit found ? 0 : 1 }' "$operations"; then
  fail "operations contains a Git read without fsmonitor disabled"
fi
grep -Fq 'VERDICT: ship | fix-first | rethink' "$contracts" || fail "reviewer verdict contract missing"
grep -Fq 'implementer corrects an implementer→reviewer result' "$contracts" || fail "full implementer correction owner missing"
grep -Fq 'Sol corrects a' "$contracts" || fail "full Sol correction owner missing"
grep -Fq 'consultant/explorer→Sol→reviewer result' "$contracts" || fail "consult/review correction composition missing"
grep -Fq 'new uniquely named' "$contracts" || fail "fresh rereview naming is undefined"
grep -Fq 'sequential attempts in the same' "$contracts" || fail "replacement auxiliary accounting is undefined"
pass "worker, investigation, consult, and review contracts"

grep -Fq '../../scripts/inspect-agent-runtime.sh' "$operations" || fail "operations does not resolve runtime inspector relatively"
grep -Fq '../../scripts/snapshot-scope.sh' "$operations" || fail "operations does not resolve scope snapshot helper relatively"
grep -Fq 'Public spawn metadata is authoritative' "$operations" || fail "operations omits public metadata rule"
grep -Fq 'Existing user-owned copies may remain installed' "$operations" || fail "operations does not explain legacy profiles"
if grep -Fq 'scripts/install-agents.sh' "$readme"; then fail "README still requires companion install"; fi
grep -Fq 'No companion-agent' "$readme" || fail "README omits simplified setup"
grep -Fq 'installation or model confirmation is required' "$readme" || fail "README omits no-confirmation setup"
grep -Fq '`jq` and Python 3' "$readme" || fail "README omits runtime dependencies"
grep -Fq '`shasum`' "$readme" || fail "README omits retained-profile maintainer dependency"
grep -Fq 'never creates a separate sidebar task' "$readme" || fail "README omits native subagent boundary"
grep -Fq 'Task size or volume alone never qualifies' "$readme" || fail "README omits Astra usage guard"
grep -Fq 'Attention Heads' "$readme" || fail "README lost Attention Heads section"
pass "user-facing setup and operations"

python3 - "$legacy_templates" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])
expected = {
    "sol-advisor-luna-implementer.toml": {
        "name": "sol_advisor_luna_implementer",
        "model": "gpt-6-luna",
        "model_reasoning_effort": "max",
    },
    "sol-advisor-terra-implementer.toml": {
        "name": "sol_advisor_terra_implementer",
        "model": "gpt-6-luna",
        "model_reasoning_effort": "high",
    },
    "sol-advisor-sol-reviewer.toml": {
        "name": "sol_advisor_sol_reviewer",
        "model": "gpt-6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
}
actual = {path.name for path in root.glob("*.toml")}
if actual != set(expected):
    raise SystemExit(f"legacy role inventory drifted: {sorted(actual)}")
for filename, pins in expected.items():
    data = tomllib.loads((root / filename).read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"legacy role {filename} has empty {field}")
    for field, expected_value in pins.items():
        if data.get(field) != expected_value:
            raise SystemExit(
                f"legacy role {filename} has {field}={data.get(field)!r}; expected {expected_value!r}"
            )
print("retained legacy role templates are valid")
PY
legacy_target=$tmp_dir/legacy-agents
grep -Fq "legacy_luna_sha256=$legacy_luna_sha256" "$legacy_installer" || fail "installer legacy Luna digest mismatch"
grep -Fq "legacy_terra_sha256=$legacy_terra_sha256" "$legacy_installer" || fail "installer legacy Terra digest mismatch"
grep -Fq "legacy_luna_v050_sha256=$legacy_luna_v050_sha256" "$legacy_installer" || fail "installer v0.5 Luna digest mismatch"
grep -Fq "legacy_terra_v050_sha256=$legacy_terra_v050_sha256" "$legacy_installer" || fail "installer v0.5 Terra digest mismatch"

sh "$legacy_installer" --target-dir "$legacy_target" >/dev/null
for role in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$legacy_templates/$role" "$legacy_target/$role" || fail "clean legacy install mismatch: $role"
done
sh "$legacy_installer" --target-dir "$legacy_target" --check >/dev/null
legacy_before=$(snapshot_legacy_target "$legacy_target")
sh "$legacy_installer" --target-dir "$legacy_target" >/dev/null
legacy_after=$(snapshot_legacy_target "$legacy_target")
[ "$legacy_before" = "$legacy_after" ] || fail "idempotent legacy install changed current roles"

selective_target=$tmp_dir/legacy-selective
sh "$legacy_installer" --target-dir "$selective_target" >/dev/null
printf '%s\n' modified >> "$selective_target/$terra_file"
selective_before=$(snapshot_legacy_target "$selective_target")
sh "$legacy_installer" --target-dir "$selective_target" --check --check-role luna --check-role sol >/dev/null
if sh "$legacy_installer" --target-dir "$selective_target" --check --check-role terra >/dev/null 2>&1; then
  fail "selective legacy check accepted conflicting Terra"
fi
if sh "$legacy_installer" --target-dir "$selective_target" --check >/dev/null 2>&1; then
  fail "all-role legacy check accepted conflicting Terra"
fi
if sh "$legacy_installer" --target-dir "$selective_target" --check-role unknown >/dev/null 2>&1; then
  fail "legacy installer accepted an unknown selective role"
fi
selective_after=$(snapshot_legacy_target "$selective_target")
[ "$selective_before" = "$selective_after" ] || fail "legacy selective checks mutated their target"

missing_target=$tmp_dir/legacy-missing
missing_before=$(snapshot_legacy_target "$missing_target")
if sh "$legacy_installer" --target-dir "$missing_target" --check >/dev/null 2>&1; then
  fail "legacy --check accepted a missing target"
fi
missing_after=$(snapshot_legacy_target "$missing_target")
[ "$missing_before" = "$missing_after" ] || fail "legacy missing-target check mutated its target"

migration_target=$tmp_dir/legacy-migration
write_legacy_roles "$migration_target"
sh "$legacy_installer" --target-dir "$migration_target" >/dev/null
for role in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$legacy_templates/$role" "$migration_target/$role" || fail "historical migration mismatch: $role"
done

v050_target=$tmp_dir/legacy-v050-migration
write_v050_roles "$v050_target"
sh "$legacy_installer" --target-dir "$v050_target" >/dev/null
for role in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$legacy_templates/$role" "$v050_target/$role" || fail "v0.5 migration mismatch: $role"
done

modified_historical=$tmp_dir/legacy-modified-historical
write_v050_roles "$modified_historical"
printf 'X' >> "$modified_historical/$terra_file"
modified_before=$(snapshot_legacy_target "$modified_historical")
if sh "$legacy_installer" --target-dir "$modified_historical" >/dev/null 2>&1; then
  fail "legacy installer replaced a modified historical role"
fi
modified_after=$(snapshot_legacy_target "$modified_historical")
[ "$modified_before" = "$modified_after" ] || fail "historical-role refusal partially mutated the target"

conflict_target=$tmp_dir/legacy-conflict
mkdir -p "$conflict_target"
cp "$legacy_templates/$luna_file" "$conflict_target/$luna_file"
printf '%s\n' modified >> "$conflict_target/$luna_file"
conflict_before=$(snapshot_legacy_target "$conflict_target")
if sh "$legacy_installer" --target-dir "$conflict_target" >/dev/null 2>&1; then
  fail "legacy installer replaced a modified current role"
fi
conflict_after=$(snapshot_legacy_target "$conflict_target")
[ "$conflict_before" = "$conflict_after" ] || fail "current-role refusal partially mutated the target"
test ! -e "$conflict_target/$terra_file" || fail "current-role refusal partially installed Terra"
test ! -e "$conflict_target/$sol_file" || fail "current-role refusal partially installed Sol"

symlink_target=$tmp_dir/legacy-symlink
mkdir -p "$symlink_target"
ln -s "$legacy_templates/$luna_file" "$symlink_target/$luna_file"
symlink_before=$(snapshot_legacy_target "$symlink_target")
if sh "$legacy_installer" --target-dir "$symlink_target" >/dev/null 2>&1; then
  fail "legacy installer accepted a symlinked destination"
fi
symlink_after=$(snapshot_legacy_target "$symlink_target")
[ "$symlink_before" = "$symlink_after" ] || fail "symlink refusal partially mutated the target"
test ! -e "$symlink_target/$terra_file" || fail "symlink refusal partially installed Terra"
test ! -e "$symlink_target/$sol_file" || fail "symlink refusal partially installed Sol"

nonregular_target=$tmp_dir/legacy-nonregular
mkdir -p "$nonregular_target"
mkfifo "$nonregular_target/$luna_file"
nonregular_before=$(snapshot_legacy_target "$nonregular_target")
if sh "$legacy_installer" --target-dir "$nonregular_target" >/dev/null 2>&1; then
  fail "legacy installer accepted a nonregular destination"
fi
nonregular_after=$(snapshot_legacy_target "$nonregular_target")
[ "$nonregular_before" = "$nonregular_after" ] || fail "nonregular refusal partially mutated the target"
test ! -e "$nonregular_target/$terra_file" || fail "nonregular refusal partially installed Terra"
test ! -e "$nonregular_target/$sol_file" || fail "nonregular refusal partially installed Sol"

legacy_codex_home=$tmp_dir/legacy-codex-home
CODEX_HOME="$legacy_codex_home" sh "$legacy_installer" >/dev/null
for role in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$legacy_templates/$role" "$legacy_codex_home/agents/$role" || fail "legacy CODEX_HOME mismatch: $role"
done
test ! -e "$legacy_codex_home/config.toml" || fail "legacy installer created config.toml"
pass "retained legacy installer migration, refusal, selective, idempotence, and atomicity regressions"

workspace_dir=$tmp_dir/review-workspace
scope_dir=$workspace_dir/declared-scope
mkdir -p "$scope_dir"
tracked_file=$scope_dir/tracked.txt
untracked_file=$scope_dir/untracked.txt
ignored_file=$scope_dir/ignored.bin
missing_file=$scope_dir/will-be-created.txt
printf '%s\n' alpha > "$tracked_file"
printf '%s\n' beta > "$untracked_file"
printf '%s\n' gamma > "$ignored_file"
scope_before=$(sh "$scope_snapshot" -- "$tracked_file" "$untracked_file" "$ignored_file" "$missing_file")
printf '%s\n' "$scope_before" | grep -Fq '"type":"file"' || fail "scope snapshot omitted files"
printf '%s\n' "$scope_before" | grep -Fq 'ignored.bin' || fail "scope snapshot omitted ignored-style artifact"
printf '%s\n' "$scope_before" | grep -Fq '"type":"missing"' || fail "scope snapshot omitted missing state"
printf '%s\n' changed > "$ignored_file"
scope_after=$(sh "$scope_snapshot" -- "$tracked_file" "$untracked_file" "$ignored_file" "$missing_file")
[ "$scope_before" != "$scope_after" ] || fail "scope snapshot missed an in-scope content mutation"
workspace_before=$(sh "$scope_snapshot" -- "$workspace_dir")
surprise_file=$workspace_dir/.outside-declared-scope.cache
printf '%s\n' surprise > "$surprise_file"
workspace_after=$(sh "$scope_snapshot" -- "$workspace_dir")
[ "$workspace_before" != "$workspace_after" ] || fail "workspace inventory missed an out-of-scope ignored mutation"
printf '%s\n' "$workspace_after" | grep -Fq '.outside-declared-scope.cache' || fail "workspace inventory omitted out-of-scope path"
git_metadata=$workspace_dir/.git
mkdir -p "$git_metadata"
printf '%s\n' changing-metadata > "$git_metadata/index"
workspace_with_git=$(sh "$scope_snapshot" -- "$workspace_dir")
printf '%s\n' "$workspace_with_git" | grep -Fq '/.git/index' || fail "workspace inventory omitted Git metadata"
printf '%s\n' "$workspace_with_git" | grep -Fq '"mode":' || fail "workspace inventory omitted permission metadata"
printf '%s\n' "$workspace_with_git" | grep -Fq '"mtime_ns":' || fail "workspace inventory omitted modification-time metadata"

metadata_file=$workspace_dir/metadata-only.txt
printf '%s\n' stable > "$metadata_file"
chmod 0644 "$metadata_file"
metadata_before=$(sh "$scope_snapshot" -- "$metadata_file")
chmod 0600 "$metadata_file"
metadata_after=$(sh "$scope_snapshot" -- "$metadata_file")
[ "$metadata_before" != "$metadata_after" ] || fail "workspace inventory missed a mode-only mutation"
for field in ctime_ns device gid inode nlink uid xattrs_sha256; do
  printf '%s\n' "$metadata_after" | grep -Fq "\"$field\":" || fail "workspace inventory omitted $field evidence"
done

identity_file=$workspace_dir/identity.txt
identity_replacement=$workspace_dir/identity-replacement.txt
printf '%s\n' same-content > "$identity_file"
printf '%s\n' same-content > "$identity_replacement"
identity_before=$(sh "$scope_snapshot" -- "$identity_file")
mv "$identity_replacement" "$identity_file"
identity_after=$(sh "$scope_snapshot" -- "$identity_file")
[ "$identity_before" != "$identity_after" ] || fail "workspace inventory missed a same-content replacement"

xattr_file=$workspace_dir/xattr.txt
printf '%s\n' xattr-content > "$xattr_file"
xattr_before=$(sh "$scope_snapshot" -- "$xattr_file")
if python3 -c 'import os, sys; sys.exit(0 if hasattr(os, "setxattr") else 1)'; then
  python3 - "$xattr_file" <<'PY'
import os
import sys

name = "user.sol_advisor_verify" if sys.platform.startswith("linux") else "com.sol-advisor.verify"
os.setxattr(sys.argv[1], name, b"changed", follow_symlinks=False)
PY
elif command -v xattr >/dev/null 2>&1; then
  xattr -w com.sol-advisor.verify changed "$xattr_file"
elif command -v setfattr >/dev/null 2>&1; then
  setfattr -n user.sol_advisor_verify -v changed "$xattr_file"
else
  fail "no supported extended-attribute writer is available for snapshot verification"
fi
xattr_after=$(sh "$scope_snapshot" -- "$xattr_file")
[ "$xattr_before" != "$xattr_after" ] || fail "workspace inventory missed an extended-attribute mutation"

external_root=$tmp_dir/review-external-artifacts
mkdir -p "$external_root"
external_target=$external_root/output.bin
printf '%s\n' original > "$external_target"
external_link=$workspace_dir/external-output
ln -s "$external_target" "$external_link"
external_before=$(sh "$scope_snapshot" -- "$workspace_dir" "$external_root")
printf '%s\n' changed > "$external_target"
external_after=$(sh "$scope_snapshot" -- "$workspace_dir" "$external_root")
[ "$external_before" != "$external_after" ] || fail "workspace inventory missed a writable external symlink-target mutation"

git_primary=$tmp_dir/review-primary-repository
git_linked=$tmp_dir/review-linked-worktree
git init -q "$git_primary"
git -C "$git_primary" config user.name 'Sol Advisor Verify'
git -C "$git_primary" config user.email 'verify@example.invalid'
printf '%s\n' initial > "$git_primary/tracked.txt"
git -C "$git_primary" add tracked.txt
git -C "$git_primary" -c commit.gpgsign=false commit -q -m initial
git -C "$git_primary" worktree add -q -b review-snapshot-fixture "$git_linked"
linked_git_dir=$(GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" rev-parse --path-format=absolute --git-dir)
linked_common_dir=$(GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" rev-parse --path-format=absolute --git-common-dir)
[ "$linked_git_dir" != "$linked_common_dir" ] || fail "linked-worktree fixture did not produce distinct Git roots"
common_before=$(sh "$scope_snapshot" -- "$linked_git_dir" "$linked_common_dir")
git -C "$git_linked" config sol-advisor.snapshot changed
common_after=$(sh "$scope_snapshot" -- "$linked_git_dir" "$linked_common_dir")
[ "$common_before" != "$common_after" ] || fail "workspace inventory missed a linked-worktree common-directory mutation"

fsmonitor_hook=$tmp_dir/review-fsmonitor-hook.sh
fsmonitor_marker=$tmp_dir/review-fsmonitor-side-effect
printf '%s\n' '#!/bin/sh' ': > "${SOL_ADVISOR_FSMONITOR_MARKER:?}"' 'exit 0' > "$fsmonitor_hook"
chmod 0700 "$fsmonitor_hook"
git -C "$git_linked" config core.fsmonitor "$fsmonitor_hook"
SOL_ADVISOR_FSMONITOR_MARKER="$fsmonitor_marker" GIT_OPTIONAL_LOCKS=0 git -C "$git_linked" status --short >/dev/null 2>&1 || true
test -e "$fsmonitor_marker" || fail "fsmonitor fixture did not demonstrate its external side effect"
rm -f "$fsmonitor_marker"

safe_git_before=$(sh "$scope_snapshot" --digest -- "$git_linked" "$linked_git_dir" "$linked_common_dir")
SOL_ADVISOR_FSMONITOR_MARKER="$fsmonitor_marker" GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" status --short --ignore-submodules=all >/dev/null
SOL_ADVISOR_FSMONITOR_MARKER="$fsmonitor_marker" GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" diff --no-ext-diff --no-textconv --ignore-submodules=all >/dev/null
GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" rev-parse --path-format=absolute --git-dir >/dev/null
GIT_OPTIONAL_LOCKS=0 git -c core.fsmonitor=false -C "$git_linked" rev-parse --path-format=absolute --git-common-dir >/dev/null
test ! -e "$fsmonitor_marker" || fail "fsmonitor-disabled Git read executed the configured hook"
safe_git_after=$(sh "$scope_snapshot" --digest -- "$git_linked" "$linked_git_dir" "$linked_common_dir")
[ "$safe_git_before" = "$safe_git_after" ] || fail "lock-free Git reads mutated protected workspace or Git metadata"

digest_before=$(sh "$scope_snapshot" --digest -- "$workspace_dir" "$external_root" "$linked_git_dir" "$linked_common_dir")
printf '%s\n' "$digest_before" | grep -Eq '^[0-9a-f]{64}$' || fail "snapshot digest mode returned an invalid digest"
digest_after=$(sh "$scope_snapshot" --digest -- "$workspace_dir" "$external_root" "$linked_git_dir" "$linked_common_dir")
[ "$digest_before" = "$digest_after" ] || fail "snapshot digest mode is unstable without mutation"

unreadable_root=$tmp_dir/review-unreadable
mkdir -p "$unreadable_root"
printf '%s\n' hidden > "$unreadable_root/content.txt"
chmod 000 "$unreadable_root"
if sh "$scope_snapshot" --digest -- "$unreadable_root" >/dev/null 2>&1; then
  chmod 0700 "$unreadable_root"
  fail "snapshot digest mode accepted an unreadable root"
fi
chmod 0700 "$unreadable_root"

if sh "$scope_snapshot" -- -unsafe >/dev/null 2>&1; then fail "scope snapshot accepted an option-like path"; fi
pass "whole-workspace snapshots and native digest mode fail closed across content, metadata, xattrs, symlinks, and linked worktrees"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/09/06
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-09-06T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK_PROMPT"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"default\",\"agent_path\":\"/root/sol_advisor\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-6-sol","effort":"max","sandbox_policy":{"type":"workspace-write"},"permission_profile":{"type":"managed"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
printf '%s\n' "$runtime_output" | jq -e --arg id "$runtime_id" '
  .thread_id == $id and .agent_role == "default"
  and .parent_thread_id == "00000000-0000-7000-8000-000000000000"
  and .agent_path == "/root/sol_advisor"
  and .model_provider == "openai"
  and .model == "gpt-6-sol" and .effort == "max"
  and .sandbox_policy_type == "workspace-write"
  and .permission_profile_type == "managed"
  and .cwd == "/fixture"
  and ((keys | sort) == ([
    "agent_path",
    "agent_role",
    "cwd",
    "effort",
    "model",
    "model_provider",
    "parent_thread_id",
    "permission_profile_type",
    "sandbox_policy_type",
    "thread_id"
  ] | sort))
' >/dev/null || fail "runtime inspector returned wrong Sol / Max evidence"
if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi

missing_sandbox_id=22222222-2222-7222-8222-222222222222
missing_sandbox_rollout=$runtime_day/rollout-2026-09-06T00-00-01-$missing_sandbox_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$missing_sandbox_id\",\"agent_role\":\"default\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-6-sol","effort":"max","permission_profile":{"type":"managed"},"cwd":"/fixture"}}' \
  > "$missing_sandbox_rollout"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$missing_sandbox_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted missing sandbox policy"
fi

missing_permission_id=33333333-3333-7333-8333-333333333333
missing_permission_rollout=$runtime_day/rollout-2026-09-06T00-00-02-$missing_permission_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$missing_permission_id\",\"agent_role\":\"default\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-6-sol","effort":"max","sandbox_policy":{"type":"workspace-write"},"cwd":"/fixture"}}' \
  > "$missing_permission_rollout"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$missing_permission_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted missing permission profile"
fi

missing_cwd_id=44444444-4444-7444-8444-444444444444
missing_cwd_rollout=$runtime_day/rollout-2026-09-06T00-00-03-$missing_cwd_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$missing_cwd_id\",\"agent_role\":\"default\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-6-sol","effort":"max","sandbox_policy":{"type":"workspace-write"},"permission_profile":{"type":"managed"}}}' \
  > "$missing_cwd_rollout"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$missing_cwd_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted missing working directory"
fi

python3 - "$runtime_sessions" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])


def session(thread_id: str, *, include_role: bool = True) -> dict:
    payload = {"id": thread_id, "agent_path": "/root/fixture", "model_provider": "openai"}
    if include_role:
        payload["agent_role"] = "default"
    return {"type": "session_meta", "payload": payload}


def turn(**overrides: object) -> dict:
    payload = {
        "model": "gpt-6-sol",
        "effort": "max",
        "sandbox_policy": {"type": "workspace-write"},
        "permission_profile": {"type": "managed"},
        "cwd": "/fixture",
    }
    payload.update(overrides)
    return {"type": "turn_context", "payload": payload}


def write(day: str, thread_id: str, records: list[dict]) -> None:
    directory = root / day
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"rollout-fixture-{thread_id}.jsonl"
    path.write_text("".join(json.dumps(record) + "\n" for record in records), encoding="utf-8")


mismatch_id = "66666666-6666-7666-8666-666666666666"
write("2026/09/07", mismatch_id, [session("11111111-1111-7111-8111-111111111111"), turn()])

multiple_id = "77777777-7777-7777-8777-777777777777"
write("2026/09/07", multiple_id, [session(multiple_id), turn()])
write("2026/09/08", multiple_id, [session(multiple_id), turn()])

model_id = "88888888-8888-7888-8888-888888888888"
write("2026/09/07", model_id, [session(model_id), turn(), turn(model="gpt-5.6-terra")])
effort_id = "99999999-9999-7999-8999-999999999999"
write("2026/09/07", effort_id, [session(effort_id), turn(), turn(effort="high")])
sandbox_id = "aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa"
write("2026/09/07", sandbox_id, [session(sandbox_id), turn(), turn(sandbox_policy={"type": "read-only"})])
permission_id = "bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb"
write("2026/09/07", permission_id, [session(permission_id), turn(), turn(permission_profile={"type": "disabled"})])
cwd_id = "cccccccc-cccc-7ccc-8ccc-cccccccccccc"
write("2026/09/07", cwd_id, [session(cwd_id), turn(), turn(cwd="/other")])

missing_model_id = "dddddddd-dddd-7ddd-8ddd-dddddddddddd"
write("2026/09/07", missing_model_id, [session(missing_model_id), turn(model=None)])
missing_effort_id = "eeeeeeee-eeee-7eee-8eee-eeeeeeeeeeee"
write("2026/09/07", missing_effort_id, [session(missing_effort_id), turn(effort=None)])
missing_role_id = "ffffffff-ffff-7fff-8fff-ffffffffffff"
write("2026/09/07", missing_role_id, [session(missing_role_id, include_role=False), turn()])
ambiguous_session_id = "12121212-1212-7212-8212-121212121212"
write(
    "2026/09/07",
    ambiguous_session_id,
    [session(ambiguous_session_id), session(ambiguous_session_id), turn()],
)
missing_session_id = "13131313-1313-7313-8313-131313131313"
write("2026/09/07", missing_session_id, [turn()])
missing_turn_id = "14141414-1414-7414-8414-141414141414"
write("2026/09/07", missing_turn_id, [session(missing_turn_id)])
malformed_id = "15151515-1515-7515-8515-151515151515"
malformed_path = root / "2026/09/07" / f"rollout-fixture-{malformed_id}.jsonl"
malformed_path.write_text('{"type":"session_meta"\n', encoding="utf-8")
PY

zero_id=55555555-5555-7555-8555-555555555555
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$zero_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted zero rollout matches"
fi

for rejection in \
  '66666666-6666-7666-8666-666666666666:session-id mismatch' \
  '77777777-7777-7777-8777-777777777777:multiple rollout matches' \
  '88888888-8888-7888-8888-888888888888:conflicting models' \
  '99999999-9999-7999-8999-999999999999:conflicting efforts' \
  'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa:conflicting sandbox policies' \
  'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb:conflicting permission profiles' \
  'cccccccc-cccc-7ccc-8ccc-cccccccccccc:conflicting working directories' \
  'dddddddd-dddd-7ddd-8ddd-dddddddddddd:missing model' \
  'eeeeeeee-eeee-7eee-8eee-eeeeeeeeeeee:missing effort' \
  'ffffffff-ffff-7fff-8fff-ffffffffffff:missing role' \
  '12121212-1212-7212-8212-121212121212:ambiguous session metadata' \
  '13131313-1313-7313-8313-131313131313:missing session metadata' \
  '14141414-1414-7414-8414-141414141414:missing turn context' \
  '15151515-1515-7515-8515-151515151515:malformed JSON'; do
  rejection_id=${rejection%%:*}
  rejection_label=${rejection#*:}
  if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$rejection_id" >/dev/null 2>&1; then
    fail "runtime inspector accepted $rejection_label"
  fi
done
pass "runtime inspector Sol / Max routing and zero/multiple/mismatch/missing/conflict refusals"

sh -n "$legacy_installer"
sh -n "$runtime_inspector"
sh -n "$scope_snapshot"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor v0.7.1 dynamic orchestration checks completed in $tmp_dir"
