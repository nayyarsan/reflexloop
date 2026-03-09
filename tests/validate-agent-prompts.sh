#!/usr/bin/env bash
set -e

MAX_LINES="${MAX_LINES:-80}"

check_sections() {
  local file=$1
  shift
  for section in "$@"; do
    grep -q "## $section" "$file" || { echo "MISSING section '## $section' in $file"; exit 1; }
    echo "OK: $file has '## $section'"
  done
}

check_size() {
  local file=$1
  # Count non-empty, non-comment lines (exclude HTML comments and blank lines)
  local lines
  lines=$(grep -v '^\s*$' "$file" | grep -v '^\s*<!--' | grep -v '^\s*-->' | wc -l)
  if [ "$lines" -gt "$MAX_LINES" ]; then
    echo "FAIL: $file exceeds MAX_LINES=$MAX_LINES (actual: $lines lines)"
    exit 1
  fi
  echo "OK: $file size is $lines lines (limit: $MAX_LINES)"
}

check_sections "context/agents/dev-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Constraints" "Output Format" "Project-local rules"
check_sections "context/agents/critique-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format" "Project-local rules"
check_sections "context/agents/refiner-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format" "Project-local rules"

check_size "context/agents/dev-agent/system-prompt.md"
check_size "context/agents/critique-agent/system-prompt.md"
check_size "context/agents/refiner-agent/system-prompt.md"

echo "All agent prompts valid."
