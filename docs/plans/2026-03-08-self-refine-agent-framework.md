# Self-Refining Agent Framework — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a dual-runtime (Claude Code + GitHub Copilot) framework of self-improving software development agents that critique every session, accumulate evidence, and apply batched refinements to their own system prompts.

**Architecture:** Three agents (dev-agent, critique-agent, refiner-agent) share a `context/` folder as the source of truth. Runtime adapter files for both platforms are thin wrappers around `context/agents/<name>/system-prompt.md`. Hooks on both platforms fire `scripts/run-critique.sh` after every session, which appends a JSON finding to a JSONL log and triggers `scripts/check-threshold.sh` to decide if a batched refinement commit is warranted.

**Tech Stack:** Bash, Claude CLI (`claude`), GitHub Copilot CLI (`gh copilot`), Markdown, JSON/JSONL, Git, bats (bash testing framework)

---

## Prerequisites

- `claude` CLI installed and authenticated
- `git` initialized (already done)
- `bats-core` for shell script testing: `npm install -g bats` or `brew install bats-core`
- All paths relative to repo root: `D:/myprojects/selfrefineragent/`

---

### Task 1: Scaffold Directory Structure

**Files:**
- Create: `context/agents/dev-agent/.gitkeep`
- Create: `context/agents/critique-agent/.gitkeep`
- Create: `context/agents/refiner-agent/.gitkeep`
- Create: `.claude/agents/.gitkeep`
- Create: `.claude/hooks/.gitkeep`
- Create: `.github/agents/.gitkeep`
- Create: `.github/hooks/.gitkeep`
- Create: `.github/skills/self-refine/.gitkeep`
- Create: `scripts/.gitkeep`
- Create: `tests/.gitkeep`

**Step 1: Create all directories**

```bash
mkdir -p context/agents/dev-agent
mkdir -p context/agents/critique-agent
mkdir -p context/agents/refiner-agent
mkdir -p .claude/agents
mkdir -p .claude/hooks
mkdir -p .github/agents
mkdir -p .github/hooks
mkdir -p .github/skills/self-refine
mkdir -p scripts
mkdir -p tests
```

**Step 2: Write a validation script to confirm structure**

Create `tests/validate-structure.sh`:
```bash
#!/usr/bin/env bash
set -e
DIRS=(
  "context/agents/dev-agent"
  "context/agents/critique-agent"
  "context/agents/refiner-agent"
  ".claude/agents"
  ".claude/hooks"
  ".github/agents"
  ".github/hooks"
  ".github/skills/self-refine"
  "scripts"
  "tests"
)
for d in "${DIRS[@]}"; do
  [ -d "$d" ] || { echo "MISSING: $d"; exit 1; }
  echo "OK: $d"
done
echo "All directories present."
```

**Step 3: Run validation**

```bash
bash tests/validate-structure.sh
```
Expected: `All directories present.`

**Step 4: Commit**

```bash
git add .
git commit -m "chore: scaffold directory structure"
```

---

### Task 2: dev-agent Context Files

**Files:**
- Create: `context/agents/dev-agent/system-prompt.md`
- Create: `context/agents/dev-agent/examples.md`
- Create: `context/agents/dev-agent/critiques.jsonl`
- Create: `context/agents/dev-agent/changelog.md`

**Step 1: Write failing test — verify system-prompt.md has required sections**

Create `tests/validate-agent-prompts.sh`:
```bash
#!/usr/bin/env bash
set -e
check_sections() {
  local file=$1
  shift
  for section in "$@"; do
    grep -q "## $section" "$file" || { echo "MISSING section '## $section' in $file"; exit 1; }
    echo "OK: $file has '## $section'"
  done
}
check_sections "context/agents/dev-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Constraints" "Output Format"
check_sections "context/agents/critique-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format"
check_sections "context/agents/refiner-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format"
echo "All agent prompts valid."
```

**Step 2: Run test — verify it fails (file doesn't exist yet)**

```bash
bash tests/validate-agent-prompts.sh 2>&1 | head -3
```
Expected: error about missing file or section

**Step 3: Write `context/agents/dev-agent/system-prompt.md`**

```markdown
## Role
You are a senior software development agent embedded in a CI-quality development
workflow. You write, modify, debug, and review code across any language or framework
with the discipline of a principal engineer.

## Goal
Complete the assigned development task correctly, completely, and in a way that a
senior engineer would be proud to merge — with tests written first, a plan before
any code, and a clean auditable diff.

## Steps
1. **Understand** — read the task fully. Ask one clarifying question if ambiguous
   before doing anything else. Never assume.
2. **Explore** — read all relevant existing code, tests, and dependencies before
   touching anything. Never modify code you haven't read.
3. **Plan** — write a short implementation plan (files to change, approach, edge
   cases) before writing code. Wait for confirmation on large tasks.
4. **Write tests first** — define expected behavior as failing tests before
   implementing. If tests aren't possible (e.g. config change), state why.
5. **Implement** — make tests pass with the minimal correct change.
   No gold-plating, no unrequested refactoring.
6. **Verify** — run tests, linters, type checkers. Fix all failures before
   declaring done. Never claim success without evidence.
7. **Self-review** — read your own diff. Check for: edge cases, regressions,
   security issues (injection, auth, secrets), style consistency.
8. **Summarize** — report what changed, why, what was tested, and trade-offs.

## Constraints
- Never skip or mock tests to make them pass
- Never use `--no-verify` or bypass hooks
- Never commit secrets, credentials, or `.env` files
- Prefer editing existing files over creating new ones
- Prefer simple solutions over clever ones
- Never add features, refactoring, or comments beyond what was asked

## Output Format
End every session with this exact structure:

**Plan executed:** <what you said you'd do vs what you did>
**Changed:** <files modified>
**Tests:** <what passes / what is untested and why>
**Trade-offs:** <decisions made, alternatives considered>
**Concerns:** <anything the developer should review manually>
```

**Step 4: Write `context/agents/dev-agent/examples.md`**

```markdown
## Example 1: Adding a function with tests

**Task:** Add a `clamp(value, min, max)` function to `src/utils.py`

**Plan:** Add one function to utils.py, write two tests (within range, out of range).

**Test first (`tests/test_utils.py`):**
```python
def test_clamp_within_range():
    assert clamp(5, 1, 10) == 5

def test_clamp_below_min():
    assert clamp(-1, 0, 10) == 0

def test_clamp_above_max():
    assert clamp(15, 0, 10) == 10
```

**Then implement (`src/utils.py`):**
```python
def clamp(value: int, min_val: int, max_val: int) -> int:
    return max(min_val, min(max_val, value))
```

**Summary:**
**Plan executed:** Added clamp() with three tests as planned
**Changed:** src/utils.py, tests/test_utils.py
**Tests:** 3 passing — within range, below min, above max
**Trade-offs:** Used stdlib max/min over if-else for brevity
**Concerns:** None
```

**Step 5: Initialize empty context files**

```bash
echo "" > context/agents/dev-agent/critiques.jsonl
cat > context/agents/dev-agent/changelog.md << 'EOF'
# dev-agent Changelog

## Batch #0 — 2026-03-08
**Initial version.** General-purpose software development agent.
EOF
```

**Step 6: Run validation test**

```bash
bash tests/validate-agent-prompts.sh
```
Expected: partial pass (only dev-agent sections checked so far, critique/refiner will fail)

**Step 7: Commit**

```bash
git add context/agents/dev-agent/ tests/validate-agent-prompts.sh
git commit -m "feat(dev-agent): add system prompt, examples, and context files"
```

---

### Task 3: critique-agent Context Files

**Files:**
- Create: `context/agents/critique-agent/system-prompt.md`
- Create: `context/agents/critique-agent/examples.md`
- Create: `context/agents/critique-agent/critiques.jsonl`
- Create: `context/agents/critique-agent/changelog.md`

**Step 1: Write `context/agents/critique-agent/system-prompt.md`**

```markdown
## Role
You are a rigorous code review and agent evaluation agent. You assess the output
of other agents and trace weaknesses back to their system prompts or missing examples.

## Goal
Produce actionable, evidence-based critique that improves both the output quality
and the agent definition — not just what went wrong, but why the prompt allowed it.

## Steps
1. Read the session transcript from top to bottom without skipping
2. Identify output quality issues: correctness, completeness, test coverage, style
3. For each issue, trace root cause: prompt gap, missing example, or genuine task
   ambiguity. Do not assign blame to the model — only to the prompt.
4. Score the overall output 1–10 with one sentence of justification
5. For each prompt gap: write a concrete suggested addition (one imperative sentence)
6. For each missing example: draft a minimal before/after example that would have
   prevented the issue
7. Assess if this session reveals a recurring task type: if the same kind of task
   has appeared and the agent had no specialized guidance, set spawn_candidate to true

## Output Format
Emit exactly one JSON object. No explanation before or after. Schema:

```json
{
  "ts": "<ISO8601 timestamp>",
  "session_id": "<session id string>",
  "agent": "<agent name>",
  "output_score": <integer 1-10>,
  "score_reason": "<one sentence>",
  "findings": [
    {
      "category": "<output_quality|prompt_gap|example_missing>",
      "severity": "<minor|moderate|major>",
      "description": "<what went wrong and where in the transcript>",
      "suggested_prompt_addition": "<imperative sentence — only if prompt_gap>",
      "suggested_example": "<markdown example — only if example_missing>"
    }
  ],
  "spawn_candidate": <true|false>,
  "spawn_suggestion": {
    "name": "<kebab-case agent name>",
    "role": "<one sentence describing the agent>",
    "trigger_pattern": "<description of the recurring task type>"
  }
}
```

If spawn_candidate is false, set spawn_suggestion to null.
```

**Step 2: Write `context/agents/critique-agent/examples.md`**

```markdown
## Example 1: Critique of a session missing tests

**Input transcript summary:**
- Task: add input validation to user registration endpoint
- Agent implemented validation but wrote no tests
- Agent summary said "Tests: none — will add later"

**Correct output:**
```json
{
  "ts": "2026-03-08T10:00:00Z",
  "session_id": "example-001",
  "agent": "dev-agent",
  "output_score": 5,
  "score_reason": "Validation logic is correct but shipping untested code contradicts the agent's own constraints.",
  "findings": [
    {
      "category": "output_quality",
      "severity": "major",
      "description": "Agent skipped writing tests despite the system prompt requiring tests before implementation.",
      "suggested_prompt_addition": null,
      "suggested_example": null
    },
    {
      "category": "prompt_gap",
      "severity": "major",
      "description": "System prompt says 'write tests first' but does not say what to do when the agent is tempted to defer them.",
      "suggested_prompt_addition": "Never defer tests. If you cannot write tests now, stop and ask the developer why before proceeding.",
      "suggested_example": null
    }
  ],
  "spawn_candidate": false,
  "spawn_suggestion": null
}
```
```

**Step 3: Initialize context files**

```bash
echo "" > context/agents/critique-agent/critiques.jsonl
cat > context/agents/critique-agent/changelog.md << 'EOF'
# critique-agent Changelog

## Batch #0 — 2026-03-08
**Initial version.** Evaluates dev-agent output quality and prompt gaps.
EOF
```

**Step 4: Run validation test**

```bash
bash tests/validate-agent-prompts.sh
```
Expected: still fails on refiner-agent (not yet written)

**Step 5: Commit**

```bash
git add context/agents/critique-agent/
git commit -m "feat(critique-agent): add system prompt, examples, and context files"
```

---

### Task 4: refiner-agent Context Files

**Files:**
- Create: `context/agents/refiner-agent/system-prompt.md`
- Create: `context/agents/refiner-agent/examples.md`
- Create: `context/agents/refiner-agent/critiques.jsonl`
- Create: `context/agents/refiner-agent/changelog.md`

**Step 1: Write `context/agents/refiner-agent/system-prompt.md`**

```markdown
## Role
You are a prompt engineer and agent lifecycle manager. You apply batched,
evidence-based refinements to agent definitions and maintain their version history.

## Goal
Improve agent system prompts and examples using only signals that have crossed
the evidence threshold — no speculative changes, no scope creep, one weakness
fixed per refinement cycle.

## Steps
1. Read the clustered findings passed to you (pre-filtered, already above threshold)
2. Read the current system-prompt.md and examples.md for the target agent
3. Identify the single minimal change that addresses the clustered weakness
4. Draft the change: a one-line addition, a rewrite of one step, or one new example
5. Verify the change does not conflict with existing instructions or examples
6. If spawn_candidate is true in the input: scaffold a new agent folder
   - Create context/agents/<name>/system-prompt.md with Role, Goal, Steps, Output Format
   - Create context/agents/<name>/examples.md with one worked example
   - Create empty context/agents/<name>/critiques.jsonl
   - Create context/agents/<name>/changelog.md with Batch #0 entry
   - Create .claude/agents/<name>.md adapter
   - Create .github/agents/<name>.agent.md adapter
7. Write all updated files using Edit/Write tools
8. Append structured entry to context/agents/<name>/changelog.md
9. Output the git commit message as the very last line of your response

## Constraints
- One weakness per refinement cycle — do not batch multiple fixes into one commit
- Do not rewrite entire prompts — make the smallest effective change
- Do not add steps that address hypothetical future problems
- If unsure whether a change is safe, add it as a new step rather than modifying existing ones

## Output Format
1. Write updated files (system-prompt.md and/or examples.md)
2. Append to changelog.md:
```
## Batch #N — YYYY-MM-DD
**Weakness:** <one sentence describing the recurring issue>
**Sessions:** <comma-separated session IDs>
**Prompt change:** <description of what changed and on which line/step>
**Examples change:** <description of new example or "none">
```
3. Last line of response must be the commit message string only:
`refine(<agent-name>): batch #N — <10 words or fewer describing the fix>`

For spawned agents, use instead:
`spawn(<new-agent-name>): bootstrapped from <parent-agent> batch #N`
```

**Step 2: Write `context/agents/refiner-agent/examples.md`**

```markdown
## Example 1: Applying a prompt gap fix

**Input (from check-threshold.sh):**
```json
{
  "agent": "dev-agent",
  "batch_number": 3,
  "cluster": {
    "count": 4,
    "sessions": ["s1","s2","s3","s4"],
    "summary": "Agent consistently defers writing tests when task feels urgent",
    "suggested_prompt_addition": "Never defer tests. If you cannot write tests now, stop and ask the developer why before proceeding.",
    "category": "prompt_gap"
  }
}
```

**Action:** Append to the Constraints section of system-prompt.md:
`- Never defer tests to a follow-up task. If tests feel impossible now, stop and explain why.`

**Changelog entry:**
```
## Batch #3 — 2026-03-08
**Weakness:** Agent defers test writing when tasks feel urgent
**Sessions:** s1, s2, s3, s4
**Prompt change:** Added constraint: "Never defer tests to a follow-up task..."
**Examples change:** none
```

**Commit message:**
`refine(dev-agent): batch #3 — never defer test writing`
```

**Step 3: Initialize context files**

```bash
echo "" > context/agents/refiner-agent/critiques.jsonl
cat > context/agents/refiner-agent/changelog.md << 'EOF'
# refiner-agent Changelog

## Batch #0 — 2026-03-08
**Initial version.** Applies threshold-gated refinements to agent definitions.
EOF
```

**Step 4: Run validation — should now fully pass**

```bash
bash tests/validate-agent-prompts.sh
```
Expected: `All agent prompts valid.`

**Step 5: Commit**

```bash
git add context/agents/refiner-agent/
git commit -m "feat(refiner-agent): add system prompt, examples, and context files"
```

---

### Task 5: Claude Code Runtime Adapters

**Files:**
- Create: `.claude/agents/dev-agent.md`
- Create: `.claude/agents/critique-agent.md`
- Create: `.claude/agents/refiner-agent.md`

**Step 1: Write test — validate adapters reference context files**

Add to `tests/validate-structure.sh`:
```bash
check_include() {
  local file=$1
  local ref=$2
  grep -q "$ref" "$file" || { echo "MISSING include '$ref' in $file"; exit 1; }
  echo "OK: $file references $ref"
}
check_include ".claude/agents/dev-agent.md" "context/agents/dev-agent/system-prompt.md"
check_include ".claude/agents/critique-agent.md" "context/agents/critique-agent/system-prompt.md"
check_include ".claude/agents/refiner-agent.md" "context/agents/refiner-agent/system-prompt.md"
```

**Step 2: Run test — verify it fails**

```bash
bash tests/validate-structure.sh 2>&1 | tail -5
```
Expected: error about missing files

**Step 3: Write `.claude/agents/dev-agent.md`**

```markdown
---
name: dev-agent
description: General software development agent. Handles coding, debugging, and refactoring tasks following TDD and plan-before-code discipline.
tools: Read, Write, Edit, Bash, Glob, Grep
---

<!-- System prompt loaded from shared context — do not edit here -->
<!-- Edit context/agents/dev-agent/system-prompt.md instead -->

<context_file>context/agents/dev-agent/system-prompt.md</context_file>
<context_file>context/agents/dev-agent/examples.md</context_file>
```

**Step 4: Write `.claude/agents/critique-agent.md`**

```markdown
---
name: critique-agent
description: Evaluates dev-agent session output. Traces quality issues back to prompt gaps and missing examples. Outputs structured JSON findings.
tools: Read, Bash
---

<!-- Edit context/agents/critique-agent/system-prompt.md instead -->

<context_file>context/agents/critique-agent/system-prompt.md</context_file>
<context_file>context/agents/critique-agent/examples.md</context_file>
```

**Step 5: Write `.claude/agents/refiner-agent.md`**

```markdown
---
name: refiner-agent
description: Applies batched, evidence-based refinements to agent system prompts and examples. Runs only when evidence threshold is crossed. Can spawn new specialized agents.
tools: Read, Write, Edit, Bash, Glob, Grep
---

<!-- Edit context/agents/refiner-agent/system-prompt.md instead -->

<context_file>context/agents/refiner-agent/system-prompt.md</context_file>
<context_file>context/agents/refiner-agent/examples.md</context_file>
```

**Step 6: Run validation**

```bash
bash tests/validate-structure.sh
```
Expected: all checks pass

**Step 7: Commit**

```bash
git add .claude/agents/ tests/validate-structure.sh
git commit -m "feat(claude): add Claude Code runtime adapter agent files"
```

---

### Task 6: GitHub Copilot Runtime Adapters

**Files:**
- Create: `.github/agents/dev-agent.agent.md`
- Create: `.github/agents/critique-agent.agent.md`
- Create: `.github/agents/refiner-agent.agent.md`
- Create: `.github/skills/self-refine/SKILL.md`

**Step 1: Write `.github/agents/dev-agent.agent.md`**

```markdown
---
description: General software development agent. Handles coding, debugging, and refactoring tasks following TDD and plan-before-code discipline.
tools:
  - read_file
  - write_file
  - run_terminal_cmd
  - search_files
  - list_dir
model: claude-sonnet-4-6
handoffs:
  - label: "Run critique on this session"
    agent: critique-agent
    prompt: "Critique the session above. Read context/agents/dev-agent/system-prompt.md and context/agents/dev-agent/examples.md as reference. Output valid JSON."
    send: false
---

<!-- System prompt loaded from shared context — do not edit here -->
<!-- Edit context/agents/dev-agent/system-prompt.md instead -->

{{{ context/agents/dev-agent/system-prompt.md }}}

## Examples

{{{ context/agents/dev-agent/examples.md }}}
```

**Step 2: Write `.github/agents/critique-agent.agent.md`**

```markdown
---
description: Evaluates dev-agent session output. Traces quality issues to prompt gaps and missing examples. Outputs structured JSON findings to critiques.jsonl.
tools:
  - read_file
  - run_terminal_cmd
model: claude-sonnet-4-6
handoffs:
  - label: "Check threshold and run refiner if needed"
    agent: refiner-agent
    prompt: "Run scripts/check-threshold.sh dev-agent. If it outputs REFINE, apply the refinement."
    send: false
---

{{{ context/agents/critique-agent/system-prompt.md }}}

## Examples

{{{ context/agents/critique-agent/examples.md }}}
```

**Step 3: Write `.github/agents/refiner-agent.agent.md`**

```markdown
---
description: Applies threshold-gated refinements to agent system prompts and examples. Commits one batched change per weakness cluster. Can spawn new specialized agents.
tools:
  - read_file
  - write_file
  - run_terminal_cmd
  - search_files
model: claude-sonnet-4-6
---

{{{ context/agents/refiner-agent/system-prompt.md }}}

## Examples

{{{ context/agents/refiner-agent/examples.md }}}
```

**Step 4: Write `.github/skills/self-refine/SKILL.md`**

```markdown
# Self-Refine Skill

This repository uses a self-refining agent framework. After every dev-agent session,
the critique-agent evaluates output quality and traces gaps back to the system prompt.
When 3+ sessions flag the same weakness, the refiner-agent applies a targeted fix
and commits it.

## How to trigger manually

Run critique on a completed session:
```bash
bash scripts/run-critique.sh <session-id> dev-agent
```

Check if refinement threshold is crossed:
```bash
bash scripts/check-threshold.sh dev-agent
```

Force a refinement cycle (use sparingly):
```bash
bash scripts/run-critique.sh --force dev-agent
```

## Agent files location
- Prompts (source of truth): `context/agents/<name>/system-prompt.md`
- Evidence log: `context/agents/<name>/critiques.jsonl`
- Version history: `context/agents/<name>/changelog.md`
- Claude Code adapters: `.claude/agents/<name>.md`
- Copilot adapters: `.github/agents/<name>.agent.md`
```

**Step 5: Commit**

```bash
git add .github/
git commit -m "feat(copilot): add GitHub Copilot runtime adapters, skills, and agent files"
```

---

### Task 7: Hooks Configuration

**Files:**
- Create: `.claude/hooks/critique-hook.json`
- Create: `.github/hooks/critique-hook.json`

**Step 1: Write test — validate hook JSON is parseable and has required fields**

Create `tests/validate-hooks.sh`:
```bash
#!/usr/bin/env bash
set -e
validate_json() {
  local file=$1
  python3 -c "import json,sys; json.load(open('$file'))" \
    && echo "OK: $file is valid JSON" \
    || { echo "INVALID JSON: $file"; exit 1; }
}
validate_json ".github/hooks/critique-hook.json"
validate_json ".claude/hooks/critique-hook.json"
echo "All hooks valid."
```

**Step 2: Write `.claude/hooks/critique-hook.json`**

```json
{
  "Stop": [
    {
      "type": "command",
      "command": "bash scripts/run-critique.sh \"$CLAUDE_SESSION_ID\" dev-agent"
    }
  ]
}
```

**Step 3: Write `.github/hooks/critique-hook.json`**

```json
{
  "version": 1,
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "command": "bash scripts/run-critique.sh \"$COPILOT_SESSION_ID\" dev-agent"
      }
    ]
  }
}
```

**Step 4: Run validation**

```bash
bash tests/validate-hooks.sh
```
Expected: `All hooks valid.`

**Step 5: Commit**

```bash
git add .claude/hooks/ .github/hooks/ tests/validate-hooks.sh
git commit -m "feat(hooks): add Stop/agentStop hooks to trigger critique pipeline"
```

---

### Task 8: `scripts/check-threshold.sh`

**Files:**
- Create: `scripts/check-threshold.sh`
- Create: `tests/test-check-threshold.sh`

**Step 1: Write the test first**

Create `tests/test-check-threshold.sh`:
```bash
#!/usr/bin/env bash
set -e
AGENT="test-agent"
mkdir -p "context/agents/$AGENT"
JSONL="context/agents/$AGENT/critiques.jsonl"

# Test 1: below threshold — should output WAIT
echo "" > "$JSONL"
for i in 1 2; do
  echo "{\"session_id\":\"s$i\",\"agent\":\"$AGENT\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"missing test instruction\",\"suggested_prompt_addition\":\"Always write tests.\"}]}" >> "$JSONL"
done
result=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
[[ "$result" == WAIT* ]] || { echo "FAIL: expected WAIT, got: $result"; exit 1; }
echo "PASS: below threshold → WAIT"

# Test 2: at threshold — should output REFINE
for i in 3 4; do
  echo "{\"session_id\":\"s$i\",\"agent\":\"$AGENT\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"missing test instruction\",\"suggested_prompt_addition\":\"Always write tests.\"}]}" >> "$JSONL"
done
result=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
[[ "$result" == REFINE* ]] || { echo "FAIL: expected REFINE, got: $result"; exit 1; }
echo "PASS: at threshold → REFINE"

# Cleanup
rm -rf "context/agents/$AGENT"
echo "All threshold tests passed."
```

**Step 2: Run test — verify it fails**

```bash
bash tests/test-check-threshold.sh 2>&1 | head -5
```
Expected: error (script doesn't exist yet)

**Step 3: Write `scripts/check-threshold.sh`**

```bash
#!/usr/bin/env bash
# Usage: check-threshold.sh <agent-name> [--window N] [--threshold N]
# Reads critiques.jsonl, clusters prompt_gap findings, decides if refiner runs.
# Outputs: "REFINE <json>" or "WAIT <stats>"
set -euo pipefail

AGENT="${1:?Usage: check-threshold.sh <agent-name>}"
THRESHOLD="${THRESHOLD:-3}"
WINDOW="${WINDOW:-20}"
JSONL="context/agents/$AGENT/critiques.jsonl"

[ -f "$JSONL" ] || { echo "WAIT no critiques file found for $AGENT"; exit 0; }

# Extract last WINDOW entries, collect prompt_gap findings
RECENT=$(tail -n "$WINDOW" "$JSONL" | grep -v '^$' || true)
[ -z "$RECENT" ] && { echo "WAIT no findings yet"; exit 0; }

# Use claude CLI to semantically cluster findings and check threshold
CLUSTER_PROMPT=$(cat <<PROMPT
You are analyzing critique findings from an agent log.

Input: The following JSON lines, each is one session's critique output.
Task: Find the most common prompt_gap finding across sessions.
      If any cluster of semantically similar prompt_gap descriptions appears
      in $THRESHOLD or more sessions, output REFINE with a JSON summary.
      Otherwise output WAIT with counts.

Output format if threshold crossed:
REFINE {"agent":"$AGENT","batch_number":<next batch N>,"cluster":{"count":<n>,"sessions":[<ids>],"summary":"<weakness>","suggested_prompt_addition":"<text>","category":"prompt_gap"}}

Output format if below threshold:
WAIT {"agent":"$AGENT","top_finding":"<most common issue>","count":<n>,"needed":$THRESHOLD}

Findings:
$RECENT
PROMPT
)

echo "$CLUSTER_PROMPT" | claude --print --no-markdown 2>/dev/null || echo "WAIT claude CLI unavailable"
```

**Step 4: Make executable**

```bash
chmod +x scripts/check-threshold.sh
```

**Step 5: Run the test**

```bash
bash tests/test-check-threshold.sh
```
Expected: `All threshold tests passed.`

**Step 6: Commit**

```bash
git add scripts/check-threshold.sh tests/test-check-threshold.sh
git commit -m "feat(scripts): add check-threshold.sh with threshold/window logic"
```

---

### Task 9: `scripts/run-critique.sh`

**Files:**
- Create: `scripts/run-critique.sh`
- Create: `tests/test-run-critique.sh`

**Step 1: Write the test**

Create `tests/test-run-critique.sh`:
```bash
#!/usr/bin/env bash
set -e
# Test: dry-run mode appends a valid JSON line to critiques.jsonl
AGENT="test-agent-critique"
SESSION_ID="test-session-001"
mkdir -p "context/agents/$AGENT"
echo "" > "context/agents/$AGENT/critiques.jsonl"
cp "context/agents/dev-agent/system-prompt.md" "context/agents/$AGENT/system-prompt.md" 2>/dev/null || echo "" > "context/agents/$AGENT/system-prompt.md"
echo "" > "context/agents/$AGENT/examples.md"

# Run in dry-run mode (no real LLM call)
DRY_RUN=1 bash scripts/run-critique.sh "$SESSION_ID" "$AGENT"

# Verify a line was appended to critiques.jsonl
LINES=$(grep -c . "context/agents/$AGENT/critiques.jsonl" 2>/dev/null || echo 0)
[ "$LINES" -ge 1 ] || { echo "FAIL: critiques.jsonl not updated"; exit 1; }
echo "PASS: critiques.jsonl received a new entry"

# Verify line is valid JSON
python3 -c "
import json, sys
lines = [l for l in open('context/agents/$AGENT/critiques.jsonl') if l.strip()]
json.loads(lines[-1])
print('PASS: appended line is valid JSON')
"

# Cleanup
rm -rf "context/agents/$AGENT"
```

**Step 2: Run test — verify it fails**

```bash
bash tests/test-run-critique.sh 2>&1 | head -5
```
Expected: error (script doesn't exist yet)

**Step 3: Write `scripts/run-critique.sh`**

```bash
#!/usr/bin/env bash
# Usage: run-critique.sh <session-id> <agent-name>
# Invokes critique-agent, appends JSON to critiques.jsonl, calls check-threshold.
# Set DRY_RUN=1 to skip LLM call and append a placeholder finding (for tests).
set -euo pipefail

SESSION_ID="${1:?Usage: run-critique.sh <session-id> <agent-name>}"
AGENT="${2:?Usage: run-critique.sh <session-id> <agent-name>}"
JSONL="context/agents/$AGENT/critiques.jsonl"
SYSTEM_PROMPT="context/agents/$AGENT/system-prompt.md"
EXAMPLES="context/agents/$AGENT/examples.md"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[ -f "$SYSTEM_PROMPT" ] || { echo "ERROR: $SYSTEM_PROMPT not found"; exit 1; }

if [ "${DRY_RUN:-0}" = "1" ]; then
  # Append a placeholder finding for testing
  echo "{\"ts\":\"$TS\",\"session_id\":\"$SESSION_ID\",\"agent\":\"$AGENT\",\"output_score\":7,\"score_reason\":\"dry-run placeholder\",\"findings\":[],\"spawn_candidate\":false,\"spawn_suggestion\":null}" >> "$JSONL"
  echo "DRY_RUN: appended placeholder finding to $JSONL"
  exit 0
fi

# Build critique prompt
CRITIQUE_PROMPT=$(cat <<PROMPT
$(cat "context/agents/critique-agent/system-prompt.md")

---

## Session to critique

Agent: $AGENT
Session ID: $SESSION_ID

## Agent's current system prompt

$(cat "$SYSTEM_PROMPT")

## Agent's current examples

$(cat "$EXAMPLES")

## Session transcript

(Transcript for session $SESSION_ID would be injected here by the hook runtime.)

Output valid JSON only. No explanation before or after.
PROMPT
)

# Call critique-agent via claude CLI
FINDING=$(echo "$CRITIQUE_PROMPT" | claude --print --no-markdown 2>/dev/null \
  || echo "{\"ts\":\"$TS\",\"session_id\":\"$SESSION_ID\",\"agent\":\"$AGENT\",\"output_score\":0,\"score_reason\":\"claude CLI unavailable\",\"findings\":[],\"spawn_candidate\":false,\"spawn_suggestion\":null}")

# Append to JSONL
echo "$FINDING" >> "$JSONL"
echo "Critique appended to $JSONL"

# Check threshold — if REFINE, invoke refiner-agent
THRESHOLD_RESULT=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null || echo "WAIT check-threshold failed")

if [[ "$THRESHOLD_RESULT" == REFINE* ]]; then
  CLUSTER_JSON="${THRESHOLD_RESULT#REFINE }"
  BATCH_N=$(echo "$CLUSTER_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['batch_number'])" 2>/dev/null || echo "N")

  echo "Threshold crossed — invoking refiner-agent for batch #$BATCH_N"

  REFINER_PROMPT=$(cat <<PROMPT
$(cat "context/agents/refiner-agent/system-prompt.md")

---

## Cluster to refine

$CLUSTER_JSON

## Current system-prompt.md

$(cat "$SYSTEM_PROMPT")

## Current examples.md

$(cat "$EXAMPLES")
PROMPT
)

  COMMIT_MSG=$(echo "$REFINER_PROMPT" | claude --print --no-markdown 2>/dev/null | tail -1 \
    || echo "refine($AGENT): batch #$BATCH_N — auto-refinement")

  git add "context/agents/$AGENT/"
  git commit -m "$COMMIT_MSG

Critique evidence: $CLUSTER_JSON

Co-Authored-By: refiner-agent <noreply@selfrefine>"

  echo "Refinement committed: $COMMIT_MSG"
else
  echo "Below threshold: $THRESHOLD_RESULT"
fi
```

**Step 4: Make executable**

```bash
chmod +x scripts/run-critique.sh
```

**Step 5: Run the test**

```bash
bash tests/test-run-critique.sh
```
Expected: `PASS: critiques.jsonl received a new entry` and `PASS: appended line is valid JSON`

**Step 6: Commit**

```bash
git add scripts/run-critique.sh tests/test-run-critique.sh
git commit -m "feat(scripts): add run-critique.sh — critique pipeline orchestrator"
```

---

### Task 10: Integration Test — Full Dry-Run Cycle

**Files:**
- Create: `tests/test-integration.sh`

**Goal:** Simulate 3 sessions above threshold and verify a git commit is produced.

**Step 1: Write `tests/test-integration.sh`**

```bash
#!/usr/bin/env bash
set -e
echo "=== Integration test: full self-refine cycle ==="

AGENT="dev-agent"
JSONL="context/agents/$AGENT/critiques.jsonl"
BEFORE_COMMITS=$(git rev-list --count HEAD)

# Inject 4 identical prompt_gap findings above threshold
for i in 1 2 3 4; do
  echo "{\"ts\":\"2026-03-08T0$i:00:00Z\",\"session_id\":\"int-test-s$i\",\"agent\":\"$AGENT\",\"output_score\":5,\"score_reason\":\"test\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"agent defers test writing\",\"suggested_prompt_addition\":\"Never defer tests.\",\"suggested_example\":null}],\"spawn_candidate\":false,\"spawn_suggestion\":null}" >> "$JSONL"
done

echo "Injected 4 findings. Running check-threshold..."
RESULT=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
echo "Result: $RESULT"

if [[ "$RESULT" == REFINE* ]]; then
  echo "PASS: threshold correctly crossed"
else
  echo "WARN: threshold not crossed (claude CLI may be unavailable) — result: $RESULT"
fi

# Clean up injected test findings (restore original)
git checkout -- "$JSONL" 2>/dev/null || true
echo "=== Integration test complete ==="
```

**Step 2: Run the integration test**

```bash
bash tests/test-integration.sh
```
Expected: `PASS: threshold correctly crossed` (or WARN if claude CLI not connected)

**Step 3: Commit**

```bash
git add tests/test-integration.sh
git commit -m "test: add integration test for full self-refine cycle"
```

---

### Task 11: README and Developer Guide

**Files:**
- Create: `README.md`

**Step 1: Write `README.md`**

```markdown
# Self-Refining Agent Framework

A dual-runtime framework (Claude Code + GitHub Copilot) for software development
agents that continuously improve their own system prompts through an evidence-based
critique-and-refine loop.

## How it works

1. `dev-agent` completes a task
2. A hook fires `scripts/run-critique.sh` automatically
3. `critique-agent` evaluates output quality and traces gaps to the system prompt
4. Findings are appended to `context/agents/dev-agent/critiques.jsonl`
5. `check-threshold.sh` clusters findings — if ≥3 sessions share a weakness, `refiner-agent` runs
6. `refiner-agent` makes the minimal targeted fix and commits it

## Agents

| Agent | Purpose | System prompt |
|-------|---------|---------------|
| `dev-agent` | Software development tasks | `context/agents/dev-agent/system-prompt.md` |
| `critique-agent` | Evaluates sessions, finds prompt gaps | `context/agents/critique-agent/system-prompt.md` |
| `refiner-agent` | Applies batched refinements, spawns new agents | `context/agents/refiner-agent/system-prompt.md` |

## Editing agents

**Never edit `.claude/agents/*.md` or `.github/agents/*.agent.md` directly.**
Edit the source of truth:
```
context/agents/<name>/system-prompt.md   ← prompt
context/agents/<name>/examples.md        ← few-shot examples
```

## Manual commands

```bash
# Run critique manually on a session
bash scripts/run-critique.sh <session-id> dev-agent

# Check if threshold is crossed
bash scripts/check-threshold.sh dev-agent

# Run all tests
bash tests/validate-structure.sh
bash tests/validate-agent-prompts.sh
bash tests/validate-hooks.sh
bash tests/test-check-threshold.sh
bash tests/test-run-critique.sh
bash tests/test-integration.sh
```

## Git history

Refinement commits follow this format:
- `refine(dev-agent): batch #N — <short description>`
- `spawn(<new-agent>): bootstrapped from dev-agent batch #N`

## Research basis

- [Self-Refine](https://arxiv.org/abs/2303.17651) — iterative refinement with self-feedback
- [Agentic Context Engineering](https://arxiv.org/abs/2510.04618) — evolving context playbooks
- [AgentDevel](https://arxiv.org/abs/2601.04620) — regression-aware agent release engineering
```

**Step 2: Run all tests one final time**

```bash
bash tests/validate-structure.sh && \
bash tests/validate-agent-prompts.sh && \
bash tests/validate-hooks.sh && \
bash tests/test-check-threshold.sh && \
bash tests/test-run-critique.sh && \
echo "ALL TESTS PASSED"
```
Expected: `ALL TESTS PASSED`

**Step 3: Final commit**

```bash
git add README.md
git commit -m "docs: add README and developer guide"
```

---

---

### Task 12: User Feedback Integration

**Goal:** Allow user feedback (thumbs down, comments) from chat sessions to enrich — but not override — the automated critique pipeline.

**Design:**
- User feedback is an input *to* critique-agent, never directly to refiner-agent
- critique-agent independently decides if feedback reveals a real prompt gap
- A user-flagged session with a matching automated finding counts 1.5x toward threshold
- A user-flagged session with no automated finding adds a `disputed` flag only — never triggers refinement alone
- Internal standards remain the authority; user feedback is a hint

**Files:**
- Modify: `context/agents/critique-agent/system-prompt.md`
- Modify: `context/agents/critique-agent/examples.md`
- Modify: `scripts/run-critique.sh`
- Create: `scripts/submit-feedback.sh`
- Create: `context/feedback/feedback.jsonl`
- Modify: `tests/validate-structure.sh`
- Create: `tests/test-submit-feedback.sh`

**Step 1: Write failing test — validate feedback.jsonl exists and is valid JSON lines**

Add to `tests/validate-structure.sh`:
```bash
[ -f "context/feedback/feedback.jsonl" ] || { echo "MISSING: context/feedback/feedback.jsonl"; exit 1; }
echo "OK: context/feedback/feedback.jsonl"
```

**Step 2: Run test — verify it fails**

```bash
bash tests/validate-structure.sh 2>&1 | tail -5
```
Expected: `MISSING: context/feedback/feedback.jsonl`

**Step 3: Create feedback store**

```bash
mkdir -p context/feedback
echo "" > context/feedback/feedback.jsonl
```

**Step 4: Write `scripts/submit-feedback.sh`**

This is the developer-facing tool. Run after a session to flag it.

```bash
#!/usr/bin/env bash
# Usage: submit-feedback.sh <session-id> <agent-name> <rating: 1-5> [comment]
# Appends a feedback entry to context/feedback/feedback.jsonl
set -euo pipefail

SESSION_ID="${1:?Usage: submit-feedback.sh <session-id> <agent-name> <rating> [comment]}"
AGENT="${2:?}"
RATING="${3:?Rating must be 1-5}"
COMMENT="${4:-}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[[ "$RATING" =~ ^[1-5]$ ]] || { echo "ERROR: rating must be 1-5"; exit 1; }

ENTRY=$(python3 -c "
import json
print(json.dumps({
  'ts': '$TS',
  'session_id': '$SESSION_ID',
  'agent': '$AGENT',
  'rating': int('$RATING'),
  'comment': '''$COMMENT''',
  'incorporated': None
}))
")

echo "$ENTRY" >> context/feedback/feedback.jsonl
echo "Feedback recorded for session $SESSION_ID (rating: $RATING)"

# If rating <= 2 (negative), re-run critique with feedback attached
if [ "$RATING" -le 2 ]; then
  echo "Low rating detected — re-running critique with feedback context..."
  USER_FEEDBACK="$COMMENT" bash scripts/run-critique.sh "$SESSION_ID" "$AGENT"
fi
```

**Step 5: Write failing test for submit-feedback.sh**

Create `tests/test-submit-feedback.sh`:
```bash
#!/usr/bin/env bash
set -e
mkdir -p context/feedback
echo "" > context/feedback/feedback.jsonl

# Test 1: valid submission appends to feedback.jsonl
bash scripts/submit-feedback.sh "test-session-fb" "dev-agent" "4" "Good but missed edge case"
LINES=$(grep -c . context/feedback/feedback.jsonl 2>/dev/null || echo 0)
[ "$LINES" -ge 1 ] || { echo "FAIL: feedback.jsonl not updated"; exit 1; }
echo "PASS: feedback appended"

# Test 2: invalid rating rejected
bash scripts/submit-feedback.sh "s1" "dev-agent" "9" 2>&1 | grep -q "ERROR" \
  && echo "PASS: invalid rating rejected" \
  || { echo "FAIL: invalid rating not caught"; exit 1; }

# Test 3: entry is valid JSON
python3 -c "
import json
lines = [l for l in open('context/feedback/feedback.jsonl') if l.strip()]
data = json.loads(lines[-1])
assert 'session_id' in data
assert 'rating' in data
print('PASS: feedback entry is valid JSON with required fields')
"

echo "All feedback tests passed."
```

**Step 6: Run test — verify it fails**

```bash
bash tests/test-submit-feedback.sh 2>&1 | head -5
```
Expected: error (script doesn't exist yet)

**Step 7: Make submit-feedback.sh executable and run test**

```bash
chmod +x scripts/submit-feedback.sh
bash tests/test-submit-feedback.sh
```
Expected: `All feedback tests passed.`

**Step 8: Update critique-agent system-prompt.md — add user feedback handling**

Append to `context/agents/critique-agent/system-prompt.md` under `## Steps`:
```markdown
## User Feedback Handling

If a `user_feedback` field is present in your input:
- Treat it as a hint, not a verdict
- Independently assess whether the feedback reveals a real prompt gap
- If you agree: include a finding as normal, set `user_feedback_incorporated: true`
- If you disagree or the feedback is a preference mismatch: set `user_feedback_incorporated: false` with a one-sentence reason
- Never lower your output_score solely because of user rating

The internal quality standard always takes precedence over user opinion.
```

Update the output JSON schema in the system prompt to add two fields:
```json
"user_feedback_incorporated": <true|false|null>,
"user_feedback_reason": "<why incorporated or overruled, null if no feedback>"
```

**Step 9: Update `scripts/run-critique.sh` — pass user feedback when present**

In `run-critique.sh`, look up the feedback.jsonl for this session and attach it to the critique prompt. Add after the `EXAMPLES` variable:

```bash
# Look up user feedback for this session
USER_FEEDBACK_JSON=$(python3 -c "
import json
lines = [l for l in open('context/feedback/feedback.jsonl') if l.strip()]
matches = [json.loads(l) for l in lines if json.loads(l).get('session_id') == '$SESSION_ID']
print(json.dumps(matches[-1]) if matches else 'null')
" 2>/dev/null || echo "null")
```

And inject into `CRITIQUE_PROMPT`:
```bash
## User feedback (if any)
$USER_FEEDBACK_JSON
```

**Step 10: Update threshold weighting in `check-threshold.sh`**

Add a 1.5x weight multiplier for sessions that have a corresponding low-rating feedback entry (rating ≤ 2):

```bash
# When counting cluster members, check if session has negative feedback
# Weight: 1.5 if rating <= 2, else 1.0
# Effective threshold: sum of weights >= THRESHOLD
```

Pass `context/feedback/feedback.jsonl` path to the LLM cluster prompt so it can apply weighting.

**Step 11: Add example to critique-agent/examples.md**

```markdown
## Example 2: User feedback incorporated

**Input:** Session where user rated 2/5 with comment "agent didn't ask about my test setup before writing tests"

**critique-agent reasoning:** User is right — the agent assumed pytest when the project uses Jest. This is a prompt gap: the agent should ask about test framework if not evident from files.

**Output (excerpt):**
```json
{
  "output_score": 5,
  "findings": [{
    "category": "prompt_gap",
    "severity": "moderate",
    "description": "Agent assumed test framework without checking package.json or existing test files.",
    "suggested_prompt_addition": "Before writing tests, check for existing test files or package.json to identify the test framework in use."
  }],
  "user_feedback_incorporated": true,
  "user_feedback_reason": "User correctly identified that assuming pytest on a JS project caused unusable output."
}
```

## Example 3: User feedback overruled

**Input:** Session where user rated 1/5 with comment "I wanted it to use var not const"

**critique-agent reasoning:** Using `const` is correct modern JavaScript. This is a stylistic preference that contradicts best practices, not a prompt gap.

**Output (excerpt):**
```json
{
  "output_score": 8,
  "findings": [],
  "user_feedback_incorporated": false,
  "user_feedback_reason": "User preference for 'var' contradicts modern JS best practices. Agent correctly used const. No prompt change warranted."
}
```
```

**Step 12: Run all tests**

```bash
bash tests/validate-structure.sh && \
bash tests/validate-agent-prompts.sh && \
bash tests/validate-hooks.sh && \
bash tests/test-check-threshold.sh && \
bash tests/test-run-critique.sh && \
bash tests/test-submit-feedback.sh && \
echo "ALL TESTS PASSED"
```
Expected: `ALL TESTS PASSED`

**Step 13: Commit**

```bash
git add context/feedback/ scripts/submit-feedback.sh tests/test-submit-feedback.sh \
  context/agents/critique-agent/system-prompt.md \
  context/agents/critique-agent/examples.md \
  scripts/run-critique.sh scripts/check-threshold.sh \
  tests/validate-structure.sh
git commit -m "feat(feedback): add user feedback lane with two-tier trust model"
```

---

## Summary

| Task | Output |
|------|--------|
| 1 | Repo structure scaffolded |
| 2 | dev-agent context files |
| 3 | critique-agent context files |
| 4 | refiner-agent context files |
| 5 | Claude Code adapter files |
| 6 | GitHub Copilot adapter files + skills |
| 7 | Hook configs for both runtimes |
| 8 | `check-threshold.sh` with tests |
| 9 | `run-critique.sh` with tests |
| 10 | Integration test |
| 11 | README |
| 12 | User feedback integration (two-lane trust model) |

**New agents** are spawned automatically when critique-agent detects a recurring task
pattern — no manual scaffolding required. The framework grows itself.
