---
name: Passear agent
description: Copilot agent to work on Passear tasks
---

# Passear Agent

## CRITICAL: CI MUST PASS BEFORE COMPLETING ANY TASK

**THE MOST IMPORTANT RULE: You MUST NOT stop working on a task until CI passes.**

Before marking ANY task as complete, you MUST:

1. Run `dart format .` to format ALL Dart files
2. Run `dart format --set-exit-if-changed .` to verify formatting passes
3. If formatting fails, run `dart format .` again and repeat step 2
4. Only after step 2 succeeds with "0 changed" can you consider the task done

### Formatting Check Loop (MANDATORY)
```bash
# Step 1: Format all files
dart format .

# Step 2: Verify formatting (must show "0 changed")
dart format --set-exit-if-changed .

# If step 2 fails, go back to step 1
# Only proceed when step 2 shows "0 changed"
```

### Why This Matters
- CI runs `dart format --set-exit-if-changed .` which WILL FAIL if files aren't formatted
- Different Dart versions format differently, always use Flutter's bundled Dart
- You CANNOT complete your work if CI is failing - keep working until it passes

### Full CI Validation Script
The repository includes `./validate_ci.sh` which runs all CI checks:
- `flutter pub get` - get dependencies
- `flutter analyze` - code analysis
- `flutter test` - run tests
- `dart format --set-exit-if-changed .` - formatting check

Run this script before completing any task. If it fails, fix the issues and run again. DO NOT STOP until it passes.

---

## Other Guidelines

### iOS Configuration
- The project requires iOS 15.0 minimum deployment target
- Always ensure the Podfile's post_install hook enforces the deployment target for all pods
- The post_install hook should include:
  ```ruby
  target.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  end
  ```
- This prevents compatibility issues with newer Xcode versions that don't support older deployment targets

### Flutter Dependency Management
- After any changes to pubspec.yaml, always document that users need to run `flutter pub get`
- If users report "Couldn't resolve the package" errors, this typically means they need to:
  1. Run `flutter pub get` to fetch dependencies
  2. Run `flutter clean` and rebuild if the error persists
  3. Delete `pubspec.lock` and run `flutter pub get` again for severe cache issues
  4. On iOS: run `cd ios && pod install && cd ..` after dependency changes
- Common causes: not running pub get after pulling changes, build cache issues, or iOS pod cache 
