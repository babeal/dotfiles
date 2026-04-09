---
name: adr
description: Create a lightweight Architectural Decision Record in the project's conversational style
argument-hint: <description of the decision>
---

Create an ADR based on the user's request: $ARGUMENTS

## Steps

1. Read existing files in `docs/adr/` to determine the next number (increment the highest).
2. Name the file `docs/adr/{NNNN}-{kebab-case-name}.md` where `{NNNN}` is zero-padded to 4 digits.
3. Read the template from `${CLAUDE_SKILL_DIR}/resources/template.md`.
4. Write the ADR following the template and style guidelines.
5. If this decision supersedes an existing ADR, update the old ADR's status to "Superseded by [ADR NNNN](NNNN-name.md)".
6. Show the user the file path and a brief summary.

## Style Guidelines

- Tone is conversational and pragmatic, not formal or academic
- First person is acceptable when sharing reasoning or experience
- Keep it lightweight — enough to understand the decision and reasoning, no more
- Link to tools/libraries/references on first mention when helpful
- Acknowledge constraints honestly (prototype scope, time, trade-offs)
- The Consequences section should be honest about downsides, not just positives
- Default status is "Proposed" if not specified, but aim for "Accepted" when making a decision
- Use today's date
