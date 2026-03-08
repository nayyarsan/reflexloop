#!/usr/bin/env bash
# Tests for safety invariants: token budget, changelog completeness, JSONL validity
set -e
cd "$(dirname "$0")/.."

TOKEN_BUDGET="${TOKEN_BUDGET:-2000}"  # max chars for system prompt (rough proxy)

echo "=== Safety checks ==="

echo "Test 1: System prompts are within token budget ($TOKEN_BUDGET chars)"
BUDGET_FAIL=0
for agent in dev-agent critique-agent refiner-agent; do
  FILE="context/agents/$agent/system-prompt.md"
  if [ -f "$FILE" ]; then
    CHARS=$(wc -c < "$FILE")
    if [ "$CHARS" -gt "$TOKEN_BUDGET" ]; then
      echo "  WARN: $agent system-prompt.md is ${CHARS} chars (budget: $TOKEN_BUDGET)"
      BUDGET_FAIL=1
    else
      echo "  OK: $agent system-prompt.md is ${CHARS} chars"
    fi
  else
    echo "  SKIP: $FILE not found"
  fi
done
[ "$BUDGET_FAIL" -eq 0 ] && echo "PASS Test 1: all prompts within budget" || echo "WARN Test 1: some prompts exceed budget (adjust TOKEN_BUDGET if intentional)"

echo ""
echo "Test 2: Changelogs exist and have at least a Batch #0 entry"
CHANGELOG_FAIL=0
for agent in dev-agent critique-agent refiner-agent; do
  FILE="context/agents/$agent/changelog.md"
  if [ ! -f "$FILE" ]; then
    echo "  FAIL: missing $FILE"
    CHANGELOG_FAIL=1
  elif ! grep -q "## Batch #0" "$FILE"; then
    echo "  FAIL: $FILE has no Batch #0 entry"
    CHANGELOG_FAIL=1
  else
    echo "  OK: $agent changelog has Batch #0"
  fi
done
[ "$CHANGELOG_FAIL" -eq 0 ] && echo "PASS Test 2: all changelogs present with Batch #0" \
  || { echo "FAIL Test 2: changelog issues found"; exit 1; }

echo ""
echo "Test 3: critiques.jsonl files are well-formed (each non-empty line is valid JSON)"
JSONL_FAIL=0
for agent in dev-agent critique-agent refiner-agent; do
  FILE="context/agents/$agent/critiques.jsonl"
  if [ ! -f "$FILE" ]; then
    echo "  SKIP: $FILE not found"
    continue
  fi
  RESULT=$(python -c "
import json, sys
bad = 0
for i, line in enumerate(open('$FILE'), 1):
    line = line.strip()
    if not line:
        continue
    try:
        json.loads(line)
    except json.JSONDecodeError as e:
        print(f'  line {i}: {e}')
        bad += 1
sys.exit(bad)
" 2>&1 || true)
  if [ -n "$RESULT" ]; then
    echo "  FAIL: $FILE has malformed lines:"
    echo "$RESULT"
    JSONL_FAIL=1
  else
    echo "  OK: $agent critiques.jsonl is well-formed"
  fi
done
[ "$JSONL_FAIL" -eq 0 ] && echo "PASS Test 3: all JSONL files well-formed" \
  || { echo "FAIL Test 3: malformed JSONL found"; exit 1; }

echo ""
echo "Test 4: feedback.jsonl is well-formed"
FEEDBACK="context/feedback/feedback.jsonl"
if [ -f "$FEEDBACK" ]; then
  python -c "
import json
bad = 0
for i, line in enumerate(open('$FEEDBACK'), 1):
    line = line.strip()
    if not line: continue
    try: json.loads(line)
    except Exception as e:
        print(f'  line {i}: {e}')
        bad += 1
import sys; sys.exit(bad)
" && echo "PASS Test 4: feedback.jsonl well-formed" \
  || { echo "FAIL Test 4: malformed feedback.jsonl"; exit 1; }
else
  echo "SKIP Test 4: feedback.jsonl not found"
fi

echo ""
echo "=== Safety checks complete ==="
