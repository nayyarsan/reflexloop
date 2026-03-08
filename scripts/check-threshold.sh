#!/usr/bin/env bash
# Usage: check-threshold.sh <agent-name>
# Reads critiques.jsonl, counts prompt_gap findings, outputs REFINE or WAIT.
# THRESHOLD: min sessions with same-category finding to trigger refinement (default 3)
# WINDOW: look at last N sessions only (default 20)
set -euo pipefail

AGENT="${1:?Usage: check-threshold.sh <agent-name>}"
THRESHOLD="${THRESHOLD:-3}"
WINDOW="${WINDOW:-20}"
JSONL="context/agents/$AGENT/critiques.jsonl"

if [ ! -f "$JSONL" ]; then
  echo "WAIT no critiques file found for $AGENT"
  exit 0
fi

# Extract recent entries and count prompt_gap findings using Python
RESULT=$(python -c "
import json, sys, os

jsonl_path = '$JSONL'
threshold = int('$THRESHOLD')
window = int('$WINDOW')

lines = []
with open(jsonl_path) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                lines.append(json.loads(line))
            except json.JSONDecodeError:
                pass

recent = lines[-window:]
if not recent:
    print('WAIT no findings yet')
    sys.exit(0)

# Count prompt_gap findings by suggested_prompt_addition (cluster by text similarity)
from collections import defaultdict
clusters = defaultdict(list)

for entry in recent:
    session_id = entry.get('session_id', 'unknown')
    for finding in entry.get('findings', []):
        if finding.get('category') == 'prompt_gap':
            key = finding.get('suggested_prompt_addition', finding.get('description', ''))[:80]
            clusters[key].append({
                'session_id': session_id,
                'description': finding.get('description', ''),
                'suggested_prompt_addition': finding.get('suggested_prompt_addition', ''),
                'severity': finding.get('severity', 'minor')
            })

if not clusters:
    top = 'no prompt_gap findings'
    print(f'WAIT {json.dumps({\"agent\": \"$AGENT\", \"top_finding\": top, \"count\": 0, \"needed\": threshold})}')
    sys.exit(0)

# Find the largest cluster
best_key = max(clusters, key=lambda k: len(clusters[k]))
best_cluster = clusters[best_key]
count = len(best_cluster)

if count >= threshold:
    sessions = list(dict.fromkeys(e['session_id'] for e in best_cluster))
    # Find next batch number from changelog
    batch_n = 1
    changelog = f'context/agents/$AGENT/changelog.md'
    if os.path.exists(changelog):
        with open(changelog) as cf:
            content = cf.read()
            import re
            batches = re.findall(r'## Batch #(\d+)', content)
            if batches:
                batch_n = max(int(b) for b in batches) + 1
    result = {
        'agent': '$AGENT',
        'batch_number': batch_n,
        'cluster': {
            'count': count,
            'sessions': sessions,
            'summary': best_cluster[0]['description'],
            'suggested_prompt_addition': best_cluster[0]['suggested_prompt_addition'],
            'category': 'prompt_gap'
        }
    }
    print(f'REFINE {json.dumps(result)}')
else:
    print(f'WAIT {json.dumps({\"agent\": \"$AGENT\", \"top_finding\": best_key, \"count\": count, \"needed\": threshold})}')
" 2>/dev/null || echo "WAIT python error during analysis")

echo "$RESULT"
