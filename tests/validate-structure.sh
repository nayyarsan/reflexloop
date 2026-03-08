#!/usr/bin/env bash
set -e
DIRS=(
  "context/agents/dev-agent"
  "context/agents/critique-agent"
  "context/agents/refiner-agent"
  ".claude/agents"
  ".claude/hooks"
  ".github/agents"
  ".github/hooks"
  ".github/skills/self-refine"
  "scripts"
  "tests"
)
for d in "${DIRS[@]}"; do
  [ -d "$d" ] || { echo "MISSING: $d"; exit 1; }
  echo "OK: $d"
done
check_include() {
  local file=$1
  local ref=$2
  grep -q "$ref" "$file" || { echo "MISSING reference '$ref' in $file"; exit 1; }
  echo "OK: $file references $ref"
}
check_include ".claude/agents/dev-agent.md" "context/agents/dev-agent/system-prompt.md"
check_include ".claude/agents/critique-agent.md" "context/agents/critique-agent/system-prompt.md"
check_include ".claude/agents/refiner-agent.md" "context/agents/refiner-agent/system-prompt.md"
[ -f "context/feedback/feedback.jsonl" ] || { echo "MISSING: context/feedback/feedback.jsonl"; exit 1; }
echo "OK: context/feedback/feedback.jsonl"
echo "All directories present."
