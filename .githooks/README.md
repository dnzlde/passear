# Git Hooks

This directory contains git hooks to help maintain code quality.

## Setup

To enable these hooks, run from the project root:

```bash
git config core.hooksPath .githooks
```

## Available Hooks

### pre-commit

Automatically formats all staged Dart files before committing.

This ensures:
- Code follows Dart style guidelines
- No formatting issues in CI/CD
- Consistent code style across the project

## Manual Formatting

If you prefer not to use the hook, format files manually:

```bash
dart format .
```

Or check formatting without changes:

```bash
dart format --set-exit-if-changed .
```
