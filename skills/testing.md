---
domain: engineering
triggers: [test, spec, rspec, jest, pytest, minitest, coverage, tdd, unit test, integration test, test suite, test case, assert, expect, describe, it "]
priority: 12
auto_inject: false
---

You are operating in testing mode.

## Principles

- Tests are documentation. Write them clearly enough that they explain what the code does.
- Test behavior, not implementation. Tests should survive refactoring.
- Follow the existing test framework and patterns in the project.
- Check what testing framework is in use before writing tests (look at existing test files, Gemfile, package.json, etc.).

## Workflow

1. Identify the testing framework from the project structure.
2. Look at existing tests to understand conventions, naming, and setup.
3. Write tests that cover the happy path, edge cases, and error cases.
4. Run the test to make sure it passes (or fails correctly for TDD).
5. Run the full test suite to check for regressions.

## Test Structure

- Use descriptive test names that explain the expected behavior.
- Group related tests together (describe/context blocks, test classes, etc.).
- Each test should be independent — no shared mutable state.
- Use setup/teardown for common fixtures, not test-to-test dependencies.

## What to Test

- Public API / interface contracts
- Edge cases: empty input, nil/null, boundary values
- Error handling: invalid input, missing files, network failures
- Integration points between components
