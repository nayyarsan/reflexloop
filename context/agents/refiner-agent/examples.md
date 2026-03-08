## Example 1: Applying a prompt gap fix

**Input (cluster summary from check-threshold.sh):**
```json
{
  "agent": "dev-agent",
  "batch_number": 3,
  "cluster": {
    "count": 4,
    "sessions": ["s1","s2","s3","s4"],
    "summary": "Agent consistently defers writing tests when task feels urgent",
    "suggested_prompt_addition": "Never defer tests. If you cannot write tests now, stop and ask the developer why before proceeding.",
    "category": "prompt_gap"
  }
}
```

**Action:** Append to the Constraints section of context/agents/dev-agent/system-prompt.md:
`- Never defer tests to a follow-up task. If tests feel impossible now, stop and explain why.`

**Changelog entry appended to context/agents/dev-agent/changelog.md:**
```
## Batch #3 — 2026-03-08
**Weakness:** Agent defers test writing when tasks feel urgent
**Sessions:** s1, s2, s3, s4
**Prompt change:** Added constraint: "Never defer tests to a follow-up task..."
**Examples change:** none
```

**Final line (commit message):**
`refine(dev-agent): batch #3 — never defer test writing`

## Example 2: Spawning a new specialized agent

**Input:**
```json
{
  "agent": "dev-agent",
  "batch_number": 5,
  "cluster": {
    "count": 5,
    "sessions": ["s10","s11","s12","s13","s14"],
    "summary": "Agent repeatedly handles database migration tasks with no migration-specific guidance",
    "category": "prompt_gap"
  },
  "spawn_candidate": true,
  "spawn_suggestion": {
    "name": "migration-agent",
    "role": "Handles database schema migrations safely with rollback planning.",
    "trigger_pattern": "Any task involving ALTER TABLE, schema changes, or migration files"
  }
}
```

**Action:** Scaffold context/agents/migration-agent/ with system-prompt.md, examples.md, empty critiques.jsonl, changelog.md (Batch #0). Create .claude/agents/migration-agent.md and .github/agents/migration-agent.agent.md adapters.

**Final line (commit message):**
`spawn(migration-agent): bootstrapped from dev-agent batch #5`
