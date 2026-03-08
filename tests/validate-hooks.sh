#!/usr/bin/env bash
set -e
validate_json() {
  local file=$1
  python -c "import json,sys; json.load(open('$file'))" \
    && echo "OK: $file is valid JSON" \
    || { echo "INVALID JSON: $file"; exit 1; }
}
validate_json ".github/hooks/critique-hook.json"
validate_json ".claude/hooks/critique-hook.json"

# Check Claude hook has Stop key
python -c "
import json
h = json.load(open('.claude/hooks/critique-hook.json'))
assert 'Stop' in h, 'Missing Stop key in Claude hook'
assert len(h['Stop']) > 0, 'Stop array is empty'
assert h['Stop'][0]['type'] == 'command', 'Stop hook type must be command'
print('OK: .claude/hooks/critique-hook.json has valid Stop hook')
"

# Check Copilot hook has version + agentStop
python -c "
import json
h = json.load(open('.github/hooks/critique-hook.json'))
assert h.get('version') == 1, 'Missing version: 1 in Copilot hook'
assert 'agentStop' in h.get('hooks', {}), 'Missing agentStop in Copilot hook'
assert len(h['hooks']['agentStop']) > 0, 'agentStop array is empty'
assert h['hooks']['agentStop'][0]['type'] == 'command', 'agentStop hook type must be command'
print('OK: .github/hooks/critique-hook.json has valid agentStop hook')
"

echo "All hooks valid."
