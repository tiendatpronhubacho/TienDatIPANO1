# TienDat build pipeline notes

This source archive keeps the existing TienDat app sources and project settings. Build changes are limited to artifact selection, asset compilation, localization placement, and IPA validation.

## Build

- Build with xtool on a macOS runner.
- The workflow records a build-start marker and selects only an IPA created/updated during this run, avoiding stale IPA selection.
- `Scripts/fix-ipa-resources.sh` compiles `Resources/Assets.xcassets` into `Assets.car`, places `.lproj` folders at the app bundle root for `Bundle.main` localization lookup, and validates the bundle identity and Mach-O executable.
- The resulting IPA is intentionally **unsigned**. If using LCSign, sign this final IPA after the resource-fix step. Any subsequent change to the app bundle invalidates an existing signature and requires signing again.

## App identity

- Display name: TienDat
- Bundle ID: `com.tiendat.ogios`
- Version: `1.1.1 (7)`
- Minimum iOS: 16.0

## Important

A successful archive check does not prove the app can be installed. Installation also depends on a valid signing certificate, provisioning profile/entitlements, and device compatibility. The macOS build logs are required to confirm the actual xtool and actool results.
