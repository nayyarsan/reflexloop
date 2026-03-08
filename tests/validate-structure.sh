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
echo "All directories present."
