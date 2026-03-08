## Example 1: Critique of a session missing tests

**Input transcript summary:**
- Task: add input validation to user registration endpoint
- Agent implemented validation but wrote no tests
- Agent summary said "Tests: none — will add later"

**Correct output:**
```json
{
  "ts": "2026-03-08T10:00:00Z",
  "session_id": "example-001",
  "agent": "dev-agent",
  "output_score": 5,
  "score_reason": "Validation logic is correct but shipping untested code contradicts the agent's own constraints.",
  "findings": [
    {
      "category": "output_quality",
      "severity": "major",
      "description": "Agent skipped writing tests despite the system prompt requiring tests before implementation.",
      "suggested_prompt_addition": null,
      "suggested_example": null
    },
    {
      "category": "prompt_gap",
      "severity": "major",
      "description": "System prompt says 'write tests first' but does not say what to do when the agent is tempted to defer them.",
      "suggested_prompt_addition": "Never defer tests. If you cannot write tests now, stop and ask the developer why before proceeding.",
      "suggested_example": null
    }
  ],
  "spawn_candidate": false,
  "spawn_suggestion": null,
  "user_feedback_incorporated": null,
  "user_feedback_reason": null
}
```

## Example 2: User feedback incorporated

**Input:** Session where user rated 2/5 with comment "agent didn't ask about my test setup before writing tests"

**critique-agent reasoning:** User is right — the agent assumed pytest when the project uses Jest. This is a prompt gap.

**Correct output (excerpt):**
```json
{
  "output_score": 5,
  "score_reason": "Agent assumed test framework without verifying, producing unusable test output.",
  "findings": [{
    "category": "prompt_gap",
    "severity": "moderate",
    "description": "Agent assumed pytest on a JavaScript project without checking package.json or existing test files.",
    "suggested_prompt_addition": "Before writing tests, check for existing test files or package.json to identify the test framework in use.",
    "suggested_example": null
  }],
  "spawn_candidate": false,
  "spawn_suggestion": null,
  "user_feedback_incorporated": true,
  "user_feedback_reason": "User correctly identified that assuming pytest on a JS project caused unusable output."
}
```

## Example 3: User feedback overruled

**Input:** Session where user rated 1/5 with comment "I wanted it to use var not const"

**Correct output (excerpt):**
```json
{
  "output_score": 8,
  "score_reason": "Agent produced correct, well-tested code following modern JavaScript standards.",
  "findings": [],
  "spawn_candidate": false,
  "spawn_suggestion": null,
  "user_feedback_incorporated": false,
  "user_feedback_reason": "User preference for 'var' contradicts modern JS best practices. Agent correctly used const. No prompt change warranted."
}
```
