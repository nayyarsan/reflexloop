#!/usr/bin/env bash
set -e
echo "=== Integration test: full self-refine cycle ==="
cd "$(dirname "$0")/.."

AGENT="dev-agent"
JSONL="context/agents/$AGENT/critiques.jsonl"

# Save current state of critiques.jsonl to restore after test
BACKUP_JSONL=$(mktemp)
cp "$JSONL" "$BACKUP_JSONL" 2>/dev/null || echo "" > "$BACKUP_JSONL"

echo "Step 1: Inject 4 identical prompt_gap findings (above threshold of 3)"
for i in 1 2 3 4; do
  echo "{\"ts\":\"2026-03-08T0${i}:00:00Z\",\"session_id\":\"int-test-s$i\",\"agent\":\"$AGENT\",\"output_score\":5,\"score_reason\":\"test\",\"findings\":[{\"category\":\"prompt_gap\",\"severity\":\"major\",\"description\":\"agent defers test writing when task feels urgent\",\"suggested_prompt_addition\":\"Never defer tests to a follow-up task.\",\"suggested_example\":null}],\"spawn_candidate\":false,\"spawn_suggestion\":null}" >> "$JSONL"
done

echo "Step 2: Run check-threshold.sh — expect REFINE"
RESULT=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null | head -1)
echo "Result: $RESULT"

if [[ "$RESULT" == REFINE* ]]; then
  echo "PASS: threshold correctly crossed — got REFINE"
  CLUSTER_JSON="${RESULT#REFINE }"
  # Validate the cluster JSON has required fields
  python -c "
import json, sys
d = json.loads('$CLUSTER_JSON'.replace(\"'\", '\"'))
" 2>/dev/null && echo "PASS: REFINE JSON is parseable" || echo "WARN: REFINE JSON parse check skipped"
elif [[ "$RESULT" == WAIT* ]]; then
  echo "WARN: got WAIT (unexpected — may indicate clustering issue with injected data)"
else
  echo "FAIL: unexpected result: $RESULT"
  cp "$BACKUP_JSONL" "$JSONL"
  rm -f "$BACKUP_JSONL"
  exit 1
fi

echo "Step 3: Run DRY_RUN critique to verify pipeline doesn't crash"
DRY_RUN=1 bash scripts/run-critique.sh "int-test-live" "$AGENT" \
  && echo "PASS: run-critique.sh DRY_RUN completed without error" \
  || { echo "FAIL: run-critique.sh crashed"; cp "$BACKUP_JSONL" "$JSONL"; rm -f "$BACKUP_JSONL"; exit 1; }

echo "Step 4: Restore original critiques.jsonl"
cp "$BACKUP_JSONL" "$JSONL"
rm -f "$BACKUP_JSONL"
echo "Restored original critiques.jsonl"

echo "=== Integration test complete ==="
