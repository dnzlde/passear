# iOS Build Fix for GitHub Actions

## Problem
The iOS build in GitHub Actions was failing due to an incompatible deployment target specification.

## Root Cause
The `ios/Runner.xcodeproj/project.pbxproj` file had mismatched iOS deployment targets:

- **Project-level settings**: `IPHONEOS_DEPLOYMENT_TARGET = 18.0` (too new)
- **Target-level settings**: `IPHONEOS_DEPLOYMENT_TARGET = 15.6`
- **Podfile**: `platform :ios, '15.0'`

iOS 18.0 SDK is not available on GitHub Actions macOS runners, causing build failures.

## Solution
Updated all `IPHONEOS_DEPLOYMENT_TARGET` values in `project.pbxproj` to `15.0`:

### Changes Made
- **Profile configuration** (project-level): `18.0` → `15.0`
- **Debug configuration** (project-level): `18.0` → `15.0`
- **Release configuration** (project-level): `18.0` → `15.0`
- **Profile configuration** (target-level): `15.6` → `15.0`
- **Debug configuration** (target-level): `15.6` → `15.0`
- **Release configuration** (target-level): `15.6` → `15.0`

### Result
All iOS deployment targets are now consistently set to `15.0`, which:
- ✅ Matches the Podfile specification
- ✅ Is compatible with GitHub Actions macOS runners
- ✅ Supports iOS 15.0 and above
- ✅ Works with the available Xcode versions on GitHub Actions

## Technical Details

### File Modified
- `ios/Runner.xcodeproj/project.pbxproj`

### Lines Changed
6 lines changed (6 insertions, 6 deletions)

### Affected Configurations
1. **Profile** (project settings)
2. **Profile** (Runner target)
3. **Debug** (project settings)
4. **Release** (project settings)
5. **Debug** (Runner target)
6. **Release** (Runner target)

## Verification
To verify the fix:
```bash
grep "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj
```

All results should show `15.0`.

## CI/CD Impact
This fix enables the `ios-build` job in `.github/workflows/ci.yml` to:
- Successfully build on GitHub Actions macOS runners
- Use `flutter build ios --release --no-codesign`
- Upload build artifacts to GitHub

## Compatibility
- **Minimum iOS Version**: 15.0
- **Compatible with**: Xcode 13.0 and later
- **GitHub Actions**: Compatible with `macos-latest` runner
