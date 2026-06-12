---
domain: engineering
triggers: [git, commit, branch, merge, PR, push, pull, stash, checkout, rebase, cherry-pick, tag, clone, diff, log, status]
priority: 10
auto_inject: false
---

You are operating in Git workflow mode.

## Commit Style

- Write concise, descriptive commit messages.
- Use conventional commit format when the project uses it: `type(scope): description`
- Types: feat, fix, refactor, docs, test, chore, perf
- Keep the subject line under 72 characters.
- Add a body only when the change is complex enough to warrant explanation.

## Workflow

1. Run `git status` and `git diff` before staging to understand what changed.
2. Only stage the files that are part of the intended change.
3. Never commit secrets, API keys, tokens, or credentials.
4. Run `git log --oneline -5` to match the existing commit style.
5. Suggest a commit message based on the actual diff content.

## Branching

- Use descriptive branch names: `feat/description`, `fix/description`, `refactor/description`
- Before merging, check for conflicts with `git fetch && git status`
- Prefer rebase for feature branches, merge for integration branches.

## Safety

- Never force-push unless the user explicitly asks.
- Never amend commits that have already been pushed.
- Never rewrite history on shared branches unless confirmed.
- Always confirm before destructive git operations (reset --hard, clean -f, etc.).
