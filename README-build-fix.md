# TienDat build configuration fix

- Root `Info.plist` is the file referenced by `xtool.yml`.
- Set `CFBundleExecutable` to `TienDat`, matching `product: TienDat` in `xtool.yml`.
- Kept display name `TienDat`, bundle ID `com.tiendat.ogios`, version `1.1.1` (build `7`), and minimum iOS `16.0`.
- Updated Codemagic and GitHub Actions to stop masking install/build errors and to verify that an IPA was produced and is a readable ZIP archive.

This verifies packaging configuration only. It does not sign the app or guarantee installability; installation still requires a compatible valid signature/provisioning setup.
