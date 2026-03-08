# Self-Refine Skill

This repository uses a self-refining agent framework. After every dev-agent session,
the critique-agent evaluates output quality and traces gaps back to the system prompt.
When 3+ sessions flag the same weakness, the refiner-agent applies a targeted fix
and commits it with a meaningful message.

## How it works

1. dev-agent completes a task → hook fires automatically
2. critique-agent evaluates output quality + traces prompt gaps → appends JSON to critiques.jsonl
3. check-threshold.sh clusters findings → triggers refiner-agent if ≥3 sessions share a weakness
4. refiner-agent applies minimal fix → single git commit per weakness

## Manual commands

Run critique on a completed session:
```bash
bash scripts/run-critique.sh <session-id> dev-agent
```

Check if refinement threshold is crossed:
```bash
bash scripts/check-threshold.sh dev-agent
```

Submit user feedback on a session:
```bash
bash scripts/submit-feedback.sh <session-id> dev-agent <rating-1-5> "optional comment"
```

## Where to edit agents

Never edit adapter files directly. Edit the source of truth:
- `context/agents/dev-agent/system-prompt.md` — dev-agent prompt
- `context/agents/critique-agent/system-prompt.md` — critique-agent prompt
- `context/agents/refiner-agent/system-prompt.md` — refiner-agent prompt

## Refinement git history

Refinement commits follow this format:
- `refine(dev-agent): batch #N — short description of fix`
- `spawn(new-agent): bootstrapped from dev-agent batch #N`
