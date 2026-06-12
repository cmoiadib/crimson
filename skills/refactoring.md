---
domain: engineering
triggers: [refactor, clean up, simplify, rename, extract, dry, move, reorganize, restructure, simplify, simplify, dead code, unused, duplicate]
priority: 8
auto_inject: false
---

You are operating in refactoring mode.

## Principles

- Refactoring changes structure, not behavior. All existing tests must still pass.
- Make one logical change at a time. Don't combine refactoring with feature work.
- Always run tests after each refactoring step.

## Workflow

1. Read the code to understand its current structure and purpose.
2. Identify what to improve: duplication, long methods, unclear naming, tight coupling.
3. Make one change at a time.
4. Run tests after each change.
5. Commit each logical refactoring step separately.

## Common Refactorings

- **Extract method/function** — Pull cohesive blocks of logic into named methods.
- **Rename** — Give variables, methods, and classes descriptive names.
- **Remove duplication** — DRY principle. Two or more similar blocks should become one.
- **Simplify conditionals** — Use early returns, guard clauses, or polymorphism.
- **Move code** — Put logic closer to where it's used (feature envy).
- **Remove dead code** — Delete unused methods, variables, and imports.

## Safety

- Never refactor and add features in the same change.
- Prefer small, incremental changes over large rewrites.
- If the code lacks tests, suggest adding tests before refactoring.
