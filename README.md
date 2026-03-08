# Self-Refining Agent Framework

A dual-runtime framework (Claude Code + GitHub Copilot) for software development
agents that continuously improve their own system prompts through an evidence-based
critique-and-refine loop — grounded in the Self-Refine and Agentic Context Engineering research.

## How it works

1. `dev-agent` completes a coding task
2. A hook fires `scripts/run-critique.sh` automatically after the session ends
3. `critique-agent` evaluates output quality and traces gaps to the system prompt
4. Findings are appended to `context/agents/dev-agent/critiques.jsonl`
5. `check-threshold.sh` clusters findings — if ≥3 sessions share a weakness, `refiner-agent` runs
6. `refiner-agent` makes the minimal targeted fix and commits it with a meaningful message

## Agents

| Agent | Purpose | Edit here |
|-------|---------|-----------|
| `dev-agent` | Software development tasks — TDD, plan-first, no secrets | `context/agents/dev-agent/system-prompt.md` |
| `critique-agent` | Evaluates sessions, traces output issues to prompt gaps | `context/agents/critique-agent/system-prompt.md` |
| `refiner-agent` | Applies threshold-gated refinements, can spawn new agents | `context/agents/refiner-agent/system-prompt.md` |

## Editing agents

**Never edit `.claude/agents/*.md` or `.github/agents/*.agent.md` directly.**

These are runtime adapters — thin wrappers that load from the source of truth:

```
context/agents/<name>/system-prompt.md   ← prompt (edit this)
context/agents/<name>/examples.md        ← few-shot examples (edit this)
context/agents/<name>/critiques.jsonl    ← append-only evidence log (do not edit)
context/agents/<name>/changelog.md       ← auto-maintained version history
```

## User feedback

Flag a session as poor quality to accelerate critique:

```bash
bash scripts/submit-feedback.sh <session-id> dev-agent <rating-1-5> "optional comment"
```

Ratings ≤ 2 re-trigger the critique pipeline with your comment attached. The critique-agent
independently decides whether to incorporate or overrule the feedback — your internal
quality standards always take precedence over user opinion.

## Manual commands

```bash
# Run critique manually on a completed session
bash scripts/run-critique.sh <session-id> dev-agent

# Check if refinement threshold is crossed
bash scripts/check-threshold.sh dev-agent

# Force check with lower threshold
THRESHOLD=1 bash scripts/check-threshold.sh dev-agent

# Run all tests
bash tests/validate-structure.sh
bash tests/validate-agent-prompts.sh
bash tests/validate-hooks.sh
bash tests/test-check-threshold.sh
bash tests/test-run-critique.sh
bash tests/test-integration.sh
```

## Git history

Refinement commits follow predictable formats:
```
refine(dev-agent): batch #N — short description of what was fixed
spawn(new-agent): bootstrapped from dev-agent batch #N
feat(feedback): add user feedback two-lane trust model
```

## New agents

The framework grows itself. When `critique-agent` detects a recurring task type
(e.g., always writing migrations), it flags `spawn_candidate: true`. The next time
`refiner-agent` runs, it scaffolds a new agent with a starter prompt and examples —
creating all adapter files for both runtimes automatically.

## Threshold configuration

| Variable | Default | Override example |
|----------|---------|-----------------|
| `THRESHOLD` | 3 | `THRESHOLD=5 bash scripts/check-threshold.sh dev-agent` |
| `WINDOW` | 20 | `WINDOW=10 bash scripts/check-threshold.sh dev-agent` |

## Research basis

| Paper | Concept |
|-------|---------|
| [Self-Refine (2303.17651)](https://arxiv.org/abs/2303.17651) | Generate → critique → refine loop |
| [Agentic Context Engineering (2510.04618)](https://arxiv.org/abs/2510.04618) | Contexts as evolving playbooks |
| [AgentDevel (2601.04620)](https://arxiv.org/abs/2601.04620) | Regression-aware, single canonical version |
| [AgentEvolver (2511.10395)](https://arxiv.org/abs/2511.10395) | Efficient self-evolving agent lifecycle |
| [EvolveR (2510.16079)](https://arxiv.org/abs/2510.16079) | Experience-driven agent improvement |

## Runtime support

| Feature | Claude Code | GitHub Copilot |
|---------|------------|----------------|
| Agent definitions | `.claude/agents/*.md` | `.github/agents/*.agent.md` |
| Post-session hook | `Stop` hook | `agentStop` hook |
| Sequential handoff | subagent call | `handoffs` config |
| Skill bundles | `.claude/skills/` | `.github/skills/SKILL.md` |
| Source of truth | `context/agents/` | `context/agents/` (shared) |
