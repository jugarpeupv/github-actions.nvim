# Task Completion Checklist

When a task is completed, run the following commands in order:

## 1. Code Formatting
```bash
make check
```
This checks if code is properly formatted with StyLua.

If formatting issues are found:
```bash
make format
```

## 2. Linting
```bash
make lint
```
This runs luacheck to verify code quality and find potential issues.

## 3. Testing
```bash
make test
```
This runs all test suites using Busted.

For specific test files:
```bash
make test-file FILE=spec/your_test_spec.lua
```

## Important Notes
- All tests must pass before committing
- All linter warnings should be addressed
- Code must be properly formatted
- Follow the commit discipline from CLAUDE.md:
  - Only commit when all tests pass
  - All linter/compiler warnings resolved
  - Clear commit message with [STRUCTURAL] or [BEHAVIORAL] prefix
