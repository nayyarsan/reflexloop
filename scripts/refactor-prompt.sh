#!/usr/bin/env bash
# Usage: refactor-prompt.sh <agent-name>
# Invokes the refiner in compression-only mode: removes duplicates, merges
# overlapping rules, simplifies wording. Does NOT add new constraints.
# Runs validate-agent-prompts.sh before and after to confirm no regression.
set -euo pipefail

AGENT="${1:?Usage: refactor-prompt.sh <agent-name>}"
PROMPT="context/agents/$AGENT/system-prompt.md"

if [ ! -f "$PROMPT" ]; then
  echo "ERROR: no system prompt found at $PROMPT"
  exit 1
fi

WORDS_BEFORE=$(wc -w < "$PROMPT")
LINES_BEFORE=$(wc -l < "$PROMPT")

echo "=== refactor-prompt: $AGENT ==="
echo "Before: ~${WORDS_BEFORE} words / ${LINES_BEFORE} lines"
echo ""

# Pre-flight: validate current structure
echo "Running pre-flight validation..."
bash tests/validate-agent-prompts.sh
echo ""

# Build the compression prompt for the refiner
REFACTOR_PROMPT=$(cat <<EOF
You are running in REFACTOR MODE (compression only).

Target file: $PROMPT

Instructions:
- Read the current system prompt
- Remove duplicate rules (keep the most precise version)
- Merge overlapping or redundant bullets into single, tighter rules
- Simplify wording without changing meaning
- Do NOT add any new constraints or behaviors
- Do NOT remove non-negotiable safety rules
- Keep all section headers intact (Role, Goal, Steps, Constraints, Output Format, Project-local rules)
- Write the updated file back using Edit/Write tools
- Append to context/agents/$AGENT/changelog.md using this format:

## Batch #N — $(date +%Y-%m-%d)
**Type:** refactor
**Weakness:** compression pass
**Sessions:** n/a
**Severity:** n/a
**Prompt change:** removed duplicates, merged overlapping rules
**Delta:** ${WORDS_BEFORE} → <word count after> words
**Rules:** added 0 | removed <N> | merged <N>
**Examples change:** none

- Last line of your response must be exactly:
refactor($AGENT): batch #N — compressed prompt ${WORDS_BEFORE}→<Y> words
EOF
)

echo "Refactor prompt prepared. Invoke the refiner-agent with:"
echo ""
echo "---"
echo "$REFACTOR_PROMPT"
echo "---"
echo ""
echo "After the refiner runs, re-validate with:"
echo "  bash tests/validate-agent-prompts.sh"
