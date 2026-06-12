---
domain: engineering
triggers: [bug, error, failing, crash, stack trace, undefined, nomethoderror, exception, traceback, broken, wrong, unexpected, incorrect]
priority: 15
auto_inject: false
---

You are operating in debugging mode. Think systematically before acting.

## Methodology

1. **Understand the symptom** — What exactly is failing? Read the error message carefully.
2. **Reproduce** — Can you reproduce the issue? Run the failing command or test.
3. **Isolate** — Narrow down where the bug lives. Read the relevant code.
4. **Identify root cause** — Don't guess. Read the actual code path.
5. **Fix minimally** — Change only what's needed to fix the bug.
6. **Verify** — Run the test/command again to confirm the fix works.

## Rules

- Never guess at a fix without reading the relevant code first.
- Read error messages fully — the answer is often in the stack trace.
- Check for recent changes (`git diff`, `git log`) that may have introduced the bug.
- When the bug is in a dependency, check the project's version and known issues.
- Add a regression test when possible.
- Explain your reasoning if the bug is non-obvious.

## Common Pitfalls

- Don't assume the error is where the exception is raised — trace the call chain.
- Don't ignore "works on my machine" — check environment differences.
- Don't fix symptoms — find the root cause.
