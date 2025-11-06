# Contributing to Passear

Thank you for contributing to Passear! This guide will help you set up your development environment and follow best practices.

## Code Formatting

This project follows the official Dart style guide. All code must be properly formatted before committing.

### Automatic Formatting

#### Option 1: IDE Auto-Format (Recommended)

**VS Code:**
1. Install the "Dart" extension
2. Enable "Format on Save":
   - Open Settings (Cmd/Ctrl + ,)
   - Search for "format on save"
   - Check "Editor: Format On Save"

**Android Studio / IntelliJ IDEA:**
1. Install the "Dart" plugin
2. Enable format on save:
   - Go to Preferences → Tools → Actions on Save
   - Check "Reformat code"
   - Check "Optimize imports"

#### Option 2: Pre-commit Hook

Set up a git hook to automatically format files before each commit:

```bash
# From the project root
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

This will automatically format any Dart files you're committing.

### Manual Formatting

Before pushing your changes, run:

```bash
# Format all Dart files
dart format .

# Or using Flutter CLI
flutter format .
```

To check if files need formatting (same as CI):

```bash
dart format --set-exit-if-changed .
```

## Testing

Always run tests before submitting a PR:

```bash
flutter test
```

## Code Analysis

Run the analyzer to catch potential issues:

```bash
flutter analyze
```

## Pull Request Checklist

Before submitting a PR, ensure:

- [ ] All tests pass (`flutter test`)
- [ ] Code is properly formatted (`dart format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Documentation is updated (if applicable)
- [ ] Commit messages are clear and descriptive

## Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Run formatter: `dart format .`
4. Run tests: `flutter test`
5. Run analyzer: `flutter analyze`
6. Commit your changes
7. Push and create a PR

## Questions?

If you have questions or need help, please open an issue on GitHub.
