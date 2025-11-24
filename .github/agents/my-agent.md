---
name: Passear agent
description: Copilot agent to work on Passear tasks
---

# Passear Agent

1) Task is incomplete if CI/CD is broken
   - Before completing any task, ALWAYS run the CI validation script: `./validate_ci.sh`
   - The script checks: code analysis (flutter analyze), tests (flutter test), and formatting (dart format)
   - DO NOT mark the task as complete until the CI validation script passes successfully
   - If the script fails, fix the reported issues and run it again
   - Continue this cycle until all CI checks pass
2) When working with iOS configuration:
   - The project requires iOS 15.0 minimum deployment target
   - Always ensure the Podfile's post_install hook enforces the deployment target for all pods
   - The post_install hook should include:
     ```ruby
     target.build_configurations.each do |config|
       config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
     end
     ```
   - This prevents compatibility issues with newer Xcode versions that don't support older deployment targets
3) Flutter dependency management:
   - After any changes to pubspec.yaml, always document that users need to run `flutter pub get`
   - If users report "Couldn't resolve the package" errors, this typically means they need to:
     1. Run `flutter pub get` to fetch dependencies
     2. Run `flutter clean` and rebuild if the error persists
     3. Delete `pubspec.lock` and run `flutter pub get` again for severe cache issues
     4. On iOS: run `cd ios && pod install && cd ..` after dependency changes
   - Common causes: not running pub get after pulling changes, build cache issues, or iOS pod cache
4) 
