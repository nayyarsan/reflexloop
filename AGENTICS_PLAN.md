# Agentics Plan — reflexloop

Add [GitHub Agentic Workflows](https://github.com/githubnext/agentics) to the self-refining AI agent system — meta on meta.

## Prerequisites

```bash
gh extension install github/gh-aw
```

## Workflows to Add

- [ ] **Q - Workflow Optimizer** — analyzes and optimises reflexloop's own GitHub workflows
  ```bash
  gh aw add-wizard githubnext/agentics/q
  ```

- [ ] **Grumpy Reviewer** — opinionated code review on Shell/prompt engineering; catches lazy prompt patterns
  ```bash
  gh aw add-wizard githubnext/agentics/grumpy-reviewer
  ```

- [ ] **Autoloop** — iterative optimisation of critique prompts against measurable improvement metrics
  ```bash
  gh aw add-wizard githubnext/agentics/autoloop
  ```

- [ ] **Agentic Wiki Writer** — auto-generates wiki pages from shell scripts and critique loop docs
  ```bash
  gh aw add-wizard githubnext/agentics/agentic-wiki-writer
  ```

- [ ] **Daily Repo Chronicle** — newspaper-style narrative of reflexloop's own activity; great for showcasing
  ```bash
  gh aw add-wizard githubnext/agentics/daily-repo-chronicle
  ```

- [ ] **Repository Quality Improver** — rotating quality review across code, docs, security, and testing
  ```bash
  gh aw add-wizard githubnext/agentics/repository-quality-improver
  ```

- [ ] **Issue Triage** — auto-labels incoming issues and PRs
  ```bash
  gh aw add-wizard githubnext/agentics/issue-triage
  ```

- [ ] **Plan** (`/plan` command) — breaks big issues into tracked sub-tasks
  ```bash
  gh aw add-wizard githubnext/agentics/plan
  ```

- [ ] **Repo Ask** (`/repo-ask` command) — on-demand research assistant for codebase questions
  ```bash
  gh aw add-wizard githubnext/agentics/repo-ask
  ```

## Keep Workflows Updated

```bash
gh aw upgrade
gh aw update
```
