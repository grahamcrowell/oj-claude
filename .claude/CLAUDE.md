# oj-claude

Claude Code implementation of the OpenJunto coordination system. Generated artifacts and Claude-specific configuration.

## Structure

Generation prompts and validation infrastructure live in `juntogen/claude/`. This repo contains generated output and Claude-specific configuration.

## Conventions

- Generation prompts follow `step-NN-name.md` naming with sequential numbering.
- Each prompt is self-contained: lists all spec inputs, defines the task, includes a verification checklist.
- Specs live in `juntospec`; do not duplicate spec content here.
- Generated output is written by the juntogen pipeline directly into this repo's plugin tree (`.claude-plugin/`, `agents/`, `hooks/`, `bin/`, `CONDUCTOR.md`, `skills/`).
- No backlog IDs in commit messages, branch names, or PR titles.
