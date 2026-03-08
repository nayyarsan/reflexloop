#!/usr/bin/env bash
# Usage: run-critique.sh <session-id> <agent-name>
# Invokes critique-agent, appends JSON finding to critiques.jsonl, calls check-threshold.
# Set DRY_RUN=1 to skip LLM call and append a placeholder (for tests).
set -euo pipefail

SESSION_ID="${1:?Usage: run-critique.sh <session-id> <agent-name>}"
AGENT="${2:?Usage: run-critique.sh <session-id> <agent-name>}"
JSONL="context/agents/$AGENT/critiques.jsonl"
SYSTEM_PROMPT="context/agents/$AGENT/system-prompt.md"
EXAMPLES="context/agents/$AGENT/examples.md"
CRITIQUE_PROMPT_FILE="context/agents/critique-agent/system-prompt.md"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

if [ ! -f "$SYSTEM_PROMPT" ]; then
  echo "ERROR: $SYSTEM_PROMPT not found — cannot run critique"
  exit 1
fi

# Ensure critiques.jsonl exists
touch "$JSONL"

if [ "${DRY_RUN:-0}" = "1" ]; then
  # Append a placeholder finding for testing — no LLM call needed
  python -c "
import json
from datetime import datetime
entry = {
    'ts': '$TS',
    'session_id': '$SESSION_ID',
    'agent': '$AGENT',
    'output_score': 7,
    'score_reason': 'dry-run placeholder — no LLM call made',
    'findings': [],
    'spawn_candidate': False,
    'spawn_suggestion': None,
    'user_feedback_incorporated': None,
    'user_feedback_reason': None
}
print(json.dumps(entry))
" >> "$JSONL"
  echo "DRY_RUN: appended placeholder finding to $JSONL"
  exit 0
fi

# Look up user feedback for this session (if any)
USER_FEEDBACK="null"
FEEDBACK_FILE="context/feedback/feedback.jsonl"
if [ -f "$FEEDBACK_FILE" ]; then
  USER_FEEDBACK=$(python -c "
import json
lines = [l for l in open('$FEEDBACK_FILE') if l.strip()]
matches = []
for l in lines:
    try:
        d = json.loads(l)
        if d.get('session_id') == '$SESSION_ID':
            matches.append(d)
    except:
        pass
print(json.dumps(matches[-1]) if matches else 'null')
" 2>/dev/null || echo "null")
fi

# Build the critique prompt
CRITIQUE_PROMPT="$(cat "$CRITIQUE_PROMPT_FILE" 2>/dev/null || echo "Critique the session.")

---

## Session to critique

Agent: $AGENT
Session ID: $SESSION_ID
Timestamp: $TS

## Agent current system prompt

$(cat "$SYSTEM_PROMPT")

## Agent current examples

$(cat "$EXAMPLES" 2>/dev/null || echo 'No examples file.')

## User feedback (null if none)

$USER_FEEDBACK

## Session transcript

(Session transcript for $SESSION_ID would be injected here by the hook runtime.)

Output valid JSON only. No explanation before or after the JSON object."

# Call critique-agent via claude CLI
FINDING=$(echo "$CRITIQUE_PROMPT" | claude --print --no-markdown 2>/dev/null || echo "")

# Validate and fallback if LLM output is not valid JSON
if [ -n "$FINDING" ] && python -c "import json,sys; json.loads(sys.stdin.read())" <<< "$FINDING" 2>/dev/null; then
  echo "$FINDING" >> "$JSONL"
  echo "Critique appended to $JSONL"
else
  # Fallback: append a minimal valid entry so the pipeline doesn't break
  python -c "
import json
entry = {
    'ts': '$TS',
    'session_id': '$SESSION_ID',
    'agent': '$AGENT',
    'output_score': 0,
    'score_reason': 'claude CLI unavailable or returned invalid JSON',
    'findings': [],
    'spawn_candidate': False,
    'spawn_suggestion': None,
    'user_feedback_incorporated': None,
    'user_feedback_reason': None
}
print(json.dumps(entry))
" >> "$JSONL"
  echo "WARNING: claude CLI unavailable — appended fallback entry to $JSONL"
fi

# Check threshold — if REFINE, invoke refiner-agent
THRESHOLD_RESULT=$(bash scripts/check-threshold.sh "$AGENT" 2>/dev/null || echo "WAIT check-threshold failed")

if [[ "$THRESHOLD_RESULT" == REFINE* ]]; then
  CLUSTER_JSON="${THRESHOLD_RESULT#REFINE }"
  BATCH_N=$(python -c "import json,sys; print(json.loads('$CLUSTER_JSON').get('batch_number','N'))" 2>/dev/null || echo "N")

  echo "Threshold crossed — invoking refiner-agent for batch #$BATCH_N"

  REFINER_PROMPT="$(cat context/agents/refiner-agent/system-prompt.md 2>/dev/null || echo 'Refine the agent.')

---

## Cluster to refine

$CLUSTER_JSON

## Current system-prompt.md

$(cat "$SYSTEM_PROMPT")

## Current examples.md

$(cat "$EXAMPLES" 2>/dev/null || echo 'No examples.')"

  COMMIT_MSG=$(echo "$REFINER_PROMPT" | claude --print --no-markdown 2>/dev/null | tail -1 \
    || echo "refine($AGENT): batch #$BATCH_N — auto-refinement")

  # Ensure commit message is reasonable
  if [ -z "$COMMIT_MSG" ] || [ ${#COMMIT_MSG} -gt 100 ]; then
    COMMIT_MSG="refine($AGENT): batch #$BATCH_N — auto-refinement"
  fi

  git add "context/agents/$AGENT/"
  git commit -m "$COMMIT_MSG

Critique evidence: $(echo "$CLUSTER_JSON" | python -c "import json,sys; d=json.load(sys.stdin); print(f\"cluster of {d['cluster']['count']} sessions\")" 2>/dev/null || echo "see critiques.jsonl")

Co-Authored-By: refiner-agent <noreply@selfrefine>"

  echo "Refinement committed: $COMMIT_MSG"
else
  echo "Below threshold: $THRESHOLD_RESULT"
fi
