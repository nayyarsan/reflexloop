#!/usr/bin/env bash
set -e
AGENT="test-agent-threshold"
mkdir -p "context/agents/$AGENT"
JSONL="context/agents/$AGENT/critiques.jsonl"

echo "Test 1: below threshold (2 findings) should output WAIT"
echo "" > "$JSONL"
for i in 1 2; do
  echo "{\"session_id\":\"s$i\",\"agent\":\"$AGENT\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"missing test instruction\",\"suggested_prompt_addition\":\"Always write tests.\"}]}" >> "$JSONL"
done
result=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
[[ "$result" == WAIT* ]] || { echo "FAIL Test 1: expected WAIT, got: $result"; rm -rf "context/agents/$AGENT"; exit 1; }
echo "PASS Test 1: below threshold → WAIT"

echo "Test 2: at threshold (4 identical findings) should output REFINE or WAIT (claude CLI may be unavailable)"
for i in 3 4; do
  echo "{\"session_id\":\"s$i\",\"agent\":\"$AGENT\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"missing test instruction\",\"suggested_prompt_addition\":\"Always write tests.\"}]}" >> "$JSONL"
done
result=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
[[ "$result" == REFINE* ]] || [[ "$result" == WAIT* ]] || { echo "FAIL Test 2: expected REFINE or WAIT, got: $result"; rm -rf "context/agents/$AGENT"; exit 1; }
echo "PASS Test 2: at/above threshold → $result"

echo "Test 3: missing critiques.jsonl should output WAIT gracefully"
rm -f "$JSONL"
result=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
[[ "$result" == WAIT* ]] || { echo "FAIL Test 3: expected WAIT for missing file, got: $result"; rm -rf "context/agents/$AGENT"; exit 1; }
echo "PASS Test 3: missing file → WAIT"

rm -rf "context/agents/$AGENT"
echo "All threshold tests passed."
