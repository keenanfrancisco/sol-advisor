# Sol Advisor

**A fresh GPT-6 Sol / Max orchestrator runs the show and chooses every auxiliary
model and reasoning effort for you.**

Sol Advisor is a Codex-native workflow for capability-routed delivery. Invoke the
skill from any primary model. It bootstraps one fresh Sol / Max orchestrator, passes
the task and repository context to it, and never asks you to confirm a model, effort,
or lane.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

## Quick start

You need a current Codex CLI or ChatGPT desktop app with plugins and native subagents
enabled, plus `jq` and Python 3 for runtime evidence and review snapshots. Maintainer
verification of retained legacy profiles also uses `shasum`. No companion-agent
installation or model confirmation is required. The bootstrap uses a native subagent
and never creates a separate sidebar task.

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

Start a fresh task and say:

~~~text
Use $sol-advisor:orchestration to build this feature and verify it.
~~~

## What happens automatically

For every invocation, the launcher creates one fresh `gpt-6.1-sol` orchestrator at
`max` effort. It never reuses a completed orchestrator. That orchestrator owns
requirements, architecture, route selection, delegation, verification, and final
acceptance. It records its route and any auxiliary model and effort choices before
task work begins.

| Mode | Use it when | Delivery |
|---|---|---|
| `solo` | The task is best handled directly. | Sol / Max plans, executes, verifies, and accepts. |
| `delegate` | One focused auxiliary improves delivery. | A worker implements and Sol verifies, or a consultant/explorer informs Sol before it implements. |
| `audit` | Fresh scrutiny matters more than delegated execution. | Sol executes; a chosen read-only reviewer inspects the result. |
| `full` | Broad or high-risk work needs two complementary auxiliaries. | Sol chooses an explicit worker/reviewer or consultant/execution composition. |

The orchestrator chooses both model and effort. Luna handles inexpensive mechanical
or tightly bounded work; Terra handles ordinary nontrivial implementation and
debugging; Sol handles difficult synthesis, architecture, and review. Astra is
reserved for a bounded **big-think consult** when ambiguity, stakes, cross-domain
synthesis, and downstream consequences make materially better framing worth the
usage. Task size or volume alone never qualifies.

An Astra consult counts as an auxiliary and never implements. Sol either implements
after the memo or assigns one non-Astra worker; it does not silently add an entire
second review chain.

Auxiliary work substitutes for orchestrator work rather than duplicating it. One
auxiliary is the default maximum; two are allowed only for genuinely independent work
or the explicit `full` route.

## Updating

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~

Start a new task after updating so the new skill instructions are loaded. For exact
spawn contracts, routing criteria, runtime evidence, and maintainer verification, read
[advanced native operations](plugins/sol-advisor/skills/orchestration/references/operations.md).
