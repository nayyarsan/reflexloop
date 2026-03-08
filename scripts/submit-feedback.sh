#!/usr/bin/env bash
# Usage: submit-feedback.sh <session-id> <agent-name> <rating: 1-5> [comment]
# Appends a structured feedback entry to context/feedback/feedback.jsonl.
# Ratings <= 2 automatically re-trigger the critique pipeline.
# Set DRY_RUN=1 to prevent run-critique.sh from making LLM calls.
set -euo pipefail

SESSION_ID="${1:?Usage: submit-feedback.sh <session-id> <agent-name> <rating 1-5> [comment]}"
AGENT="${2:?Usage: submit-feedback.sh <session-id> <agent-name> <rating 1-5> [comment]}"
RATING="${3:?Rating must be 1-5}"
COMMENT="${4:-}"
FEEDBACK_FILE="context/feedback/feedback.jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

# Validate rating
if ! [[ "$RATING" =~ ^[1-5]$ ]]; then
  echo "ERROR: rating must be an integer between 1 and 5, got: $RATING"
  exit 1
fi

# Ensure feedback store exists
mkdir -p "$(dirname "$FEEDBACK_FILE")"
touch "$FEEDBACK_FILE"

# Append feedback entry as JSON
python -c "
import json
entry = {
    'ts': '$TS',
    'session_id': '$SESSION_ID',
    'agent': '$AGENT',
    'rating': int('$RATING'),
    'comment': r'''$COMMENT''',
    'incorporated': None
}
print(json.dumps(entry))
" >> "$FEEDBACK_FILE"

echo "Feedback recorded: session=$SESSION_ID agent=$AGENT rating=$RATING"

# Ratings <= 2 (negative) re-trigger critique with feedback attached
if [ "$RATING" -le 2 ]; then
  echo "Low rating ($RATING/5) — re-running critique with feedback context..."
  USER_FEEDBACK="$COMMENT" DRY_RUN="${DRY_RUN:-0}" bash scripts/run-critique.sh "$SESSION_ID" "$AGENT" \
    || echo "WARNING: critique re-run failed — feedback recorded but not incorporated"
fi
