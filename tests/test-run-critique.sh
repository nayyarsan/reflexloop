#!/usr/bin/env bash
set -e
AGENT="test-agent-critique"
SESSION_ID="test-session-001"
mkdir -p "context/agents/$AGENT"
cp "context/agents/dev-agent/system-prompt.md" "context/agents/$AGENT/system-prompt.md" 2>/dev/null \
  || echo "## Role\nTest agent" > "context/agents/$AGENT/system-prompt.md"
echo "" > "context/agents/$AGENT/examples.md"
echo "" > "context/agents/$AGENT/critiques.jsonl"
cp "context/agents/critique-agent/system-prompt.md" "context/agents/$AGENT/../critique-agent/system-prompt.md" 2>/dev/null || true

echo "Test 1: DRY_RUN=1 appends a valid JSON line to critiques.jsonl"
DRY_RUN=1 bash scripts/run-critique.sh "$SESSION_ID" "$AGENT"

LINES=$(grep -c . "context/agents/$AGENT/critiques.jsonl" 2>/dev/null || echo 0)
[ "$LINES" -ge 1 ] || { echo "FAIL Test 1: critiques.jsonl not updated (lines=$LINES)"; rm -rf "context/agents/$AGENT"; exit 1; }
echo "PASS Test 1: critiques.jsonl received a new entry"

echo "Test 2: appended line is valid JSON with required fields"
python -c "
import json
lines = [l for l in open('context/agents/$AGENT/critiques.jsonl') if l.strip()]
if not lines:
    print('FAIL: no lines found')
    exit(1)
data = json.loads(lines[-1])
for field in ['ts', 'session_id', 'agent', 'output_score', 'findings', 'spawn_candidate']:
    assert field in data, f'FAIL: missing field {field}'
print('PASS Test 2: all required JSON fields present')
"

echo "Test 3: missing system-prompt.md exits with error"
rm "context/agents/$AGENT/system-prompt.md"
DRY_RUN=1 bash scripts/run-critique.sh "$SESSION_ID" "$AGENT" 2>&1 | grep -q "ERROR" \
  && echo "PASS Test 3: missing system-prompt exits with error" \
  || { echo "FAIL Test 3: should have errored on missing system-prompt"; rm -rf "context/agents/$AGENT"; exit 1; }

rm -rf "context/agents/$AGENT"
echo "All run-critique tests passed."
