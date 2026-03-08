# Self-Refining Agent Framework — Design Document
**Date:** 2026-03-08
**Status:** Approved

---

## Overview

A dual-runtime (Claude Code + GitHub Copilot) framework for software development agents that continuously improve their own system prompts and examples through an evidence-based critique-and-refine loop. Agents critique every session, accumulate findings, and apply batched refinements when a weakness recurs enough to be statistically meaningful.

Grounded in:
- [Self-Refine (2303.17651)](https://arxiv.org/abs/2303.17651) — iterative refinement with self-feedback
- [Agentic Context Engineering / ACE (2510.04618)](https://arxiv.org/abs/2510.04618) — evolving contexts as playbooks
- [AgentDevel (2601.04620)](https://arxiv.org/abs/2601.04620) — regression-aware agent release engineering

---

## Goals

- Start with one general-purpose `dev-agent`, framework grows specialized agents as needed
- Critique fires automatically after every session via native hooks (no developer action required)
- Refinements apply only when a weakness recurs across ≥3 sessions (threshold-gated)
- Git history stays meaningful: one squashed commit per refinement cycle, never per session
- Works identically on Claude Code and GitHub Copilot via thin runtime adapters

---

## Repository Structure

```
selfrefineragent/
├── .claude/
│   ├── agents/
│   │   ├── dev-agent.md
│   │   ├── critique-agent.md
│   │   └── refiner-agent.md
│   └── hooks/
│       └── critique-hook.json
│
├── .github/
│   ├── agents/
│   │   ├── dev-agent.agent.md
│   │   ├── critique-agent.agent.md
│   │   └── refiner-agent.agent.md
│   ├── skills/
│   │   └── self-refine/
│   │       └── SKILL.md
│   └── hooks/
│       └── critique-hook.json
│
├── context/
│   └── agents/
│       ├── dev-agent/
│       │   ├── system-prompt.md     ← source of truth for agent prompt
│       │   ├── examples.md          ← few-shot examples
│       │   ├── critiques.jsonl      ← append-only evidence log
│       │   └── changelog.md         ← version history
│       ├── critique-agent/
│       │   ├── system-prompt.md
│       │   ├── examples.md
│       │   ├── critiques.jsonl
│       │   └── changelog.md
│       └── refiner-agent/
│           ├── system-prompt.md
│           ├── examples.md
│           ├── critiques.jsonl
│           └── changelog.md
│
└── scripts/
    ├── run-critique.sh          ← called by hooks, orchestrates critique flow
    └── check-threshold.sh       ← clusters findings, decides if refiner runs
```

**Key principle:** `context/agents/<name>/system-prompt.md` is the single source of truth for every agent's prompt. Both `.claude/agents/*.md` and `.github/agents/*.agent.md` are thin wrappers that inject these files — they contain no standalone logic.

---

## Agents

### dev-agent

**Role:** Senior software development agent. Writes, modifies, debugs, and reviews code across any language or framework with the discipline of a principal engineer.

**Goal:** Complete development tasks correctly and completely — with tests written first, a plan before code, and a clean auditable diff.

**Steps:**
1. **Understand** — read the task fully. Ask one clarifying question if ambiguous. Never assume.
2. **Explore** — read all relevant existing code, tests, and dependencies before touching anything.
3. **Plan** — write a short implementation plan (files to change, approach, edge cases) before writing code. Wait for confirmation on large tasks.
4. **Write tests first** — define expected behavior as failing tests before implementing. If tests aren't possible, state why.
5. **Implement** — make tests pass with the minimal correct change. No gold-plating, no unrequested refactoring.
6. **Verify** — run tests, linters, type checkers. Fix all failures. Never claim success without evidence.
7. **Self-review** — read your own diff. Check for edge cases, regressions, security issues (injection, auth, secrets), style consistency.
8. **Summarize** — report what changed, why, what was tested, and trade-offs.

**Constraints:**
- Never skip or mock tests to make them pass
- Never use `--no-verify` or bypass hooks
- Never commit secrets, credentials, or `.env` files
- Prefer editing existing files over creating new ones
- Prefer simple solutions over clever ones
- Never add features, refactoring, or comments beyond what was asked

**Output format:**
```
**Plan executed:** <what you said you'd do vs what you did>
**Changed:** <files modified>
**Tests:** <what passes / what is untested and why>
**Trade-offs:** <decisions made, alternatives considered>
**Concerns:** <anything the developer should review manually>
```

---

### critique-agent

**Role:** Code review and agent evaluation agent. Assesses dev-agent output and traces weaknesses back to the system prompt or missing examples.

**Goal:** Produce actionable, evidence-based critique that improves both output quality and the agent definition — not just what went wrong, but why the prompt allowed it.

**Steps:**
1. Read the session transcript top to bottom
2. Identify output quality issues: correctness, completeness, test coverage, style
3. For each issue, trace root cause: prompt gap, missing example, or genuine task ambiguity
4. Score the overall output (1–10) with justification
5. For each prompt gap: write a concrete suggested addition (one sentence, imperative)
6. For each missing example: draft a minimal before/after example that would have prevented the issue
7. Check if this session reveals a recurring task type warranting a new specialized agent

**Output format:** Single JSON object:
```json
{
  "ts": "<ISO8601>",
  "session_id": "<id>",
  "agent": "<agent-name>",
  "output_score": 7,
  "findings": [
    {
      "category": "output_quality" | "prompt_gap" | "example_missing",
      "severity": "minor" | "moderate" | "major",
      "description": "<what went wrong>",
      "suggested_prompt_addition": "<imperative sentence>",
      "suggested_example": "<markdown example>"
    }
  ],
  "spawn_candidate": false,
  "spawn_suggestion": {
    "name": "<agent-name>",
    "role": "<one sentence>",
    "trigger_pattern": "<recurring task pattern>"
  }
}
```

---

### refiner-agent

**Role:** Prompt engineer and agent lifecycle manager. Applies batched, evidence-based refinements to agent definitions and maintains version history.

**Goal:** Improve agent system prompts and examples using only signals that have crossed the evidence threshold — no speculative changes, no scope creep, one weakness fixed per refinement cycle.

**Steps:**
1. Read the clustered findings passed in (pre-filtered by `check-threshold.sh`)
2. Read the current `system-prompt.md` and `examples.md` for the target agent
3. Identify the minimal change that addresses the clustered weakness
4. Draft the change: a single addition, rewrite of one step, or new example
5. Verify the change doesn't conflict with existing instructions or examples
6. If `spawn_candidate` is flagged: scaffold a new agent folder with starter `system-prompt.md` and `examples.md`
7. Write the updated files via Edit/Write tools
8. Append a structured entry to `changelog.md`
9. Output the git commit message as the final line

**Output format:**
1. Updated files written via Edit/Write tools
2. Changelog entry:
   ```
   ## Batch #N — YYYY-MM-DD
   **Weakness:** <one sentence>
   **Sessions:** <session IDs>
   **Prompt change:** <what changed and where>
   **Examples change:** <what changed or "none">
   ```
3. Final output line — git commit message:
   ```
   refine(<agent>): batch #N — <short description>
   ```

---

## Critique Loop — End-to-End Flow

```
Developer runs dev-agent on a task
         │
         ▼
dev-agent completes → writes structured summary
         │
         ▼  (agentStop / Stop hook fires automatically)
         │
         ▼
scripts/run-critique.sh
  ├── captures session transcript
  ├── invokes critique-agent with:
  │     transcript + system-prompt.md + examples.md
  └── appends JSON finding to critiques.jsonl
         │
         ▼
scripts/check-threshold.sh
  ├── reads critiques.jsonl (last 20 sessions)
  ├── clusters findings semantically via LLM
  ├── WAIT (< 3 sessions with same weakness) → silent exit
  └── REFINE (≥ 3 sessions) → invokes refiner-agent with cluster summary
         │
         ▼
refiner-agent
  ├── reads system-prompt.md + examples.md
  ├── applies minimal targeted change
  ├── scaffolds new agent if spawn_candidate = true
  ├── appends to changelog.md
  └── outputs commit message string
         │
         ▼
run-critique.sh commits:
  git add context/agents/<name>/
  git commit -m "<refiner output message>"
```

---

## Agent Spawn Flow

When `refiner-agent` detects `spawn_candidate: true`:

```
refiner-agent
  ├── creates context/agents/<new-name>/
  │     ├── system-prompt.md   (bootstrapped from trigger pattern + examples)
  │     ├── examples.md
  │     ├── critiques.jsonl    (empty)
  │     └── changelog.md       (## Batch #0 — spawned from dev-agent)
  ├── creates .claude/agents/<new-name>.md
  ├── creates .github/agents/<new-name>.agent.md
  └── git commit: spawn(<new-name>): bootstrapped from dev-agent batch #N
```

---

## Runtime Adapters

### Claude Code adapter (`.claude/agents/dev-agent.md`)
```markdown
---
name: dev-agent
description: General software development agent. Handles coding tasks, refactoring, debugging.
tools: Read, Write, Edit, Bash, Glob, Grep
---

<system>
{{include: ../../context/agents/dev-agent/system-prompt.md}}
</system>

<examples>
{{include: ../../context/agents/dev-agent/examples.md}}
</examples>
```

### GitHub Copilot adapter (`.github/agents/dev-agent.agent.md`)
```markdown
---
description: General software development agent
tools:
  - read_file
  - write_file
  - run_terminal_cmd
  - search_files
handoffs:
  - label: "Run critique"
    agent: critique-agent
    prompt: "Critique the session above against context/agents/dev-agent/system-prompt.md"
    send: false
---

{{include: ../../context/agents/dev-agent/system-prompt.md}}

## Examples
{{include: ../../context/agents/dev-agent/examples.md}}
```

### Hooks

**`.github/hooks/critique-hook.json`:**
```json
{
  "version": 1,
  "hooks": {
    "agentStop": [{
      "type": "command",
      "command": "bash scripts/run-critique.sh $COPILOT_SESSION_ID dev-agent"
    }]
  }
}
```

**`.claude/hooks/critique-hook.json`:**
```json
{
  "Stop": [{
    "type": "command",
    "command": "bash scripts/run-critique.sh $CLAUDE_SESSION_ID dev-agent"
  }]
}
```

---

## Git Strategy

- `critiques.jsonl` is append-only, never deleted
- Refinements produce **one commit per weakness cluster**, never one per session
- Commit message format: `refine(<agent>): batch #N — <short description>`
- Spawn commits: `spawn(<new-name>): bootstrapped from <parent> batch #N`
- Only `context/agents/` is committed by the refiner — runtime adapter files only change on spawns

---

## Threshold Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `THRESHOLD` | 3 | Min sessions with same weakness to trigger refinement |
| `WINDOW` | 20 | Look back at last N sessions only |
| Clustering | LLM semantic | Groups similar findings by meaning, not exact match |

---

## Research Grounding

| Paper | Concept used |
|-------|-------------|
| [Self-Refine (2303.17651)](https://arxiv.org/abs/2303.17651) | Generate → critique → refine loop |
| [ACE (2510.04618)](https://arxiv.org/abs/2510.04618) | Contexts as evolving playbooks, incremental accumulation |
| [AgentDevel (2601.04620)](https://arxiv.org/abs/2601.04620) | Regression-awareness, single canonical version line, auditable specs |
| [AgentEvolver (2511.10395)](https://arxiv.org/abs/2511.10395) | Efficient self-evolving agent lifecycle |
| [EvolveR (2510.16079)](https://arxiv.org/abs/2510.16079) | Experience-driven agent improvement |

---

## Design Decisions — Research Grounding

This section maps each architectural choice to the research that informed it.

### Why separate agents instead of one self-critiquing model?
Inspired by **Self-Refine (2303.17651)**: the paper uses a single model for all three roles (generate, critique, refine). We separate them deliberately — each agent has a distinct system prompt and can be refined independently. If critique-agent develops a blind spot, it can be corrected without touching dev-agent.

### Why a JSONL evidence log instead of in-context memory?
Inspired by **ACE (2510.04618)**: contexts as evolving playbooks that accumulate strategies incrementally. JSONL gives us: append-only auditability, structured clustering, and a format that survives context window limits. The evidence persists across sessions and runtimes.

### Why a threshold (≥3 sessions) before applying a refinement?
Inspired by **AgentDevel (2601.04620)**: non-regression as a primary objective. A single bad session should never change a prompt. The threshold prevents prompt instability from noisy critiques while still allowing genuine recurring weaknesses to surface.

### Why a WINDOW (last 20 sessions) for clustering?
Old failures should not override recent good behaviour. The window ensures the refiner responds to the agent's current state, not its history from six months ago. This prevents the prompt from accumulating fossil constraints that no longer reflect real failure modes.

### Why one fix per refinement cycle?
Directly from **AgentDevel**: maintain a single canonical version line and minimize regressions. Batching multiple changes per commit makes it impossible to identify which change fixed or broke a behaviour. One change, one commit, one traceable cause.

### Why user feedback as a hint rather than direct input?
User preferences are not quality signals. A user preferring `var` over `const` should not weaken an agent's modern-JavaScript constraint. The two-lane trust model (critique-agent independently evaluates feedback) ensures internal standards remain the authority while still surfacing genuine user pain faster.
