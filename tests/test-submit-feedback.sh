#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

FEEDBACK_FILE="context/feedback/feedback.jsonl"
BACKUP=$(mktemp)
cp "$FEEDBACK_FILE" "$BACKUP" 2>/dev/null || echo "" > "$BACKUP"

cleanup() {
  cp "$BACKUP" "$FEEDBACK_FILE" 2>/dev/null || true
  rm -f "$BACKUP"
}
trap cleanup EXIT

echo "Test 1: valid submission appends to feedback.jsonl"
bash scripts/submit-feedback.sh "test-session-fb" "dev-agent" "4" "Good but missed edge case"
LINES=$(grep -c . "$FEEDBACK_FILE" 2>/dev/null || echo 0)
[ "$LINES" -ge 1 ] || { echo "FAIL Test 1: feedback.jsonl not updated"; exit 1; }
echo "PASS Test 1: feedback appended"

echo "Test 2: invalid rating is rejected"
bash scripts/submit-feedback.sh "s1" "dev-agent" "9" 2>&1 | grep -qi "error\|invalid\|must be" \
  && echo "PASS Test 2: invalid rating rejected" \
  || { echo "FAIL Test 2: invalid rating not caught"; exit 1; }

echo "Test 3: feedback entry is valid JSON with required fields"
python -c "
import json
lines = [l for l in open('$FEEDBACK_FILE') if l.strip()]
assert lines, 'No lines found'
data = json.loads(lines[-1])
for field in ['ts', 'session_id', 'agent', 'rating', 'comment', 'incorporated']:
    assert field in data, f'Missing field: {field}'
print('PASS Test 3: all required JSON fields present')
"

echo "Test 4: rating <= 2 triggers re-critique in DRY_RUN mode"
DRY_RUN=1 bash scripts/submit-feedback.sh "low-rating-session" "dev-agent" "2" "Agent skipped tests" \
  && echo "PASS Test 4: low-rating feedback processed without crash" \
  || { echo "FAIL Test 4: low-rating feedback crashed"; exit 1; }

echo "All feedback tests passed."
