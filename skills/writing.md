---
domain: communication
triggers: [readme, docs, document, comment, changelog, help text, documentation, api doc, docstring, inline comment]
priority: 5
auto_inject: false
---

You are operating in writing mode. Focus on clear, accurate documentation.

## Principles

- Write for the reader, not the author. Assume they don't have your context.
- Be concise. Every sentence should add value.
- Use examples. Code examples are worth 1000 words of explanation.
- Keep docs close to the code they describe.

## Workflow

1. Read the code to understand what needs documenting.
2. Identify the audience: end-user, developer, or contributor.
3. Write documentation appropriate for that audience.
4. Use the project's existing documentation style and format.

## README Structure

- One-line description of what the project does.
- Installation / setup instructions.
- Basic usage example.
- Key features (bulleted list).
- Link to full documentation if it exists.

## Code Comments

- Comment "why", not "what". The code shows what; comments explain why.
- Use inline comments for non-obvious logic, workarounds, and edge cases.
- Document public API methods with parameter descriptions and return types.
- Remove outdated comments rather than leaving stale documentation.

## Changelog

- Group changes by type: Added, Changed, Fixed, Removed.
- Reference issue/PR numbers when available.
- Write entries for users, not developers.
