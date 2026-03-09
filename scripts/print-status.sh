#!/usr/bin/env bash
# Usage: print-status.sh <agent-name>
# Prints a summary dashboard: session count, top critique clusters, last refinement, threshold settings.
set -euo pipefail

AGENT="${1:?Usage: print-status.sh <agent-name>}"
JSONL="context/agents/$AGENT/critiques.jsonl"
CHANGELOG="context/agents/$AGENT/changelog.md"
THRESHOLD="${THRESHOLD:-3}"
WINDOW="${WINDOW:-20}"

PROMPT="context/agents/$AGENT/system-prompt.md"
PROMPT_WORDS=0
PROMPT_LINES=0
if [ -f "$PROMPT" ]; then
  PROMPT_WORDS=$(wc -w < "$PROMPT")
  PROMPT_LINES=$(wc -l < "$PROMPT")
fi

echo "=== reflexloop status: $AGENT ==="
echo "Threshold: $THRESHOLD  |  Window: $WINDOW"
echo "Prompt size: ~${PROMPT_WORDS} words / ${PROMPT_LINES} lines (budget: ≤1200 tokens / ≤80 lines)"
echo ""

if [ ! -f "$JSONL" ]; then
  echo "No critiques log found at $JSONL"
  exit 0
fi

python -c "
import json, sys
from collections import defaultdict, Counter

threshold = int('$THRESHOLD')
window = int('$WINDOW')

lines = [l.strip() for l in open('$JSONL') if l.strip()]
valid = []
for l in lines:
    try: valid.append(json.loads(l))
    except: pass

total = len(valid)
recent = valid[-window:]

print(f'Total sessions critiqued : {total}')
print(f'Sessions in current window: {len(recent)}')

if not recent:
    print('No data in window.')
    sys.exit(0)

scores = [e.get('output_score', 0) for e in recent if e.get('output_score')]
if scores:
    print(f'Avg output score (window) : {sum(scores)/len(scores):.1f}/10')

# Cluster prompt_gap findings
clusters = defaultdict(list)
for entry in recent:
    sid = entry.get('session_id', '?')
    for f in entry.get('findings', []):
        if f.get('category') == 'prompt_gap':
            key = f.get('suggested_prompt_addition', f.get('description',''))[:80]
            clusters[key].append(sid)

print('')
print(f'Top prompt gaps (window of {window}):')
if clusters:
    for key, sessions in sorted(clusters.items(), key=lambda x: -len(x[1]))[:5]:
        marker = '  --> ABOVE THRESHOLD' if len(sessions) >= threshold else ''
        print(f'  [{len(sessions):2d}x] {key[:70]}{marker}')
else:
    print('  None found.')
" 2>/dev/null || echo "(python analysis unavailable)"

echo ""
echo "Last refinement batch:"
if [ -f "$CHANGELOG" ]; then
  python -c "
import re
content = open('$CHANGELOG').read()
batches = re.findall(r'(## Batch #\d+.*?)(?=## Batch #|\Z)', content, re.DOTALL)
if batches:
    print(batches[-1].strip())
else:
    print('  No refinement batches yet.')
" 2>/dev/null || grep -A4 "## Batch" "$CHANGELOG" | tail -8
else
  echo "  No changelog found."
fi

echo ""
echo "=== end of status ==="
