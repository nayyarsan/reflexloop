#!/usr/bin/env bash
set -e
check_sections() {
  local file=$1
  shift
  for section in "$@"; do
    grep -q "## $section" "$file" || { echo "MISSING section '## $section' in $file"; exit 1; }
    echo "OK: $file has '## $section'"
  done
}
check_sections "context/agents/dev-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Constraints" "Output Format"
check_sections "context/agents/critique-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format"
check_sections "context/agents/refiner-agent/system-prompt.md" \
  "Role" "Goal" "Steps" "Output Format"
echo "All agent prompts valid."
