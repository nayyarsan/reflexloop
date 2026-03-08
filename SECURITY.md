# Security Policy

## Scope

reflexloop is a local developer tool. It runs entirely on your machine — there is no server, no remote API, and no user-facing web interface. The attack surface is limited to:

- Shell scripts in `scripts/` that run as the invoking user
- LLM output from the Claude CLI being written to local files
- User-supplied values passed to `submit-feedback.sh`

## Supported Versions

| Version | Supported |
|---------|-----------|
| `main` / `master` branch | Yes |
| Older commits | No — use the latest |

## Reporting a Vulnerability

If you find a security issue (shell injection, path traversal, prompt injection that causes unintended local writes, etc.), please report it **privately** before opening a public issue.

**Preferred method:** Open a [GitHub Security Advisory](https://github.com/nayyarsan/reflexloop/security/advisories/new) on this repository.

**Response time:** I aim to acknowledge reports within 48 hours and issue a fix within 7 days for confirmed vulnerabilities.

Please include:
- A description of the vulnerability
- Steps to reproduce
- The potential impact
- A suggested fix if you have one

## Known Limitations

- `run-critique.sh` passes LLM output directly into `git commit -m`. Commit messages are sanitised to 100 characters but are otherwise untrusted input.
- The `AGENT` parameter in all scripts is validated against `[a-z-]+` to prevent path traversal.
- `USER_FEEDBACK` / `COMMENT` values from `submit-feedback.sh` are passed to Python via environment variables, not string interpolation, to prevent injection.

## Out of Scope

- Issues requiring physical access to the machine
- Issues in upstream tools (Claude CLI, GitHub Copilot, Git)
- Social engineering
