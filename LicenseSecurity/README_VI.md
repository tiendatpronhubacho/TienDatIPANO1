# Secure License v2 — Tiến Đạt IPA

## What changed
- Removes the old fail-open `isLicensed = true` stub. App access is denied until the server verifies the license.
- Adds Keychain-persisted License Key and Device ID (`ThisDeviceOnly`).
- Creates a P-256 signing key in Secure Enclave and stores only its protected key representation in Keychain.
- Adds one-time server challenges, ECDSA P-256/SHA-256 signatures, challenge expiry, single-use consumption, and per-device challenge rate limiting.
- Binds each device record to its public key. A different key cannot silently take over an existing Device ID.
- Disables the old unsigned `/v1/device/*` endpoints (HTTP 410) so attackers cannot use the legacy bypass.
- Adds Admin list/create/revoke/reactivate License and block/unblock/delete device actions.
- Fails closed when offline or when the API cannot be reached.

## Important security boundary
This is a meaningful upgrade over the original unsigned API, but it is **not equivalent to Apple App Attest**. Secure Enclave key possession helps prevent copying the private key to another device and challenge-response prevents replay; a modified app running on the same device may still invoke its signing key or patch local UI checks. Strong app-instance authenticity requires Apple App Attest attestation verification on the server, the matching App Attest entitlement in the signed provisioning profile, the correct Apple Team ID / bundle ID, and production/development environment alignment. Do not claim App Attest protection until those server checks are deployed and tested. Generic enterprise/ESign re-signing may strip or lack the required entitlement.

## Worker deployment
1. Back up the existing D1 database.
2. For an existing database created for the previous Worker, run `migration_v2.sql` once. If `public_key` already exists, omit its ALTER TABLE line. For a brand-new database, run `schema.sql` instead.
3. Replace the deployed Worker code with `worker_secure.js`.
4. Keep the existing D1 binding named `DB`.
5. Set Worker secret `ADMIN_TOKEN` to a long random value (at least 32 random bytes). Never put this token in the IPA.
6. Optionally set `ALLOWED_ORIGIN` to the exact Admin origin. The default allows same-origin Admin requests only; native iOS requests do not need browser CORS.
7. Deploy and verify `GET /health` returns `api: v2-secure`.
8. Open `/admin`, sign in, create a new test License, activate it in the app, then test revoke, block, expiry and offline behavior.

## Existing database compatibility
The Worker expects the existing `licenses` and `devices` columns used by the old Worker. It adds `devices.public_key` and the `license_challenges` table via the migration above. Do not run the fresh schema on top of an existing database as a substitute for the migration.

## Signing / build
- Project minimum iOS is 16.0. Secure Enclave P-256 is used at runtime. Devices/simulators without Secure Enclave support will fail closed rather than silently fall back to a software key.
- Bundle ID in the inspected project is `com.qingtang.3106`. Keep it stable for Keychain continuity.
- Re-signing or reinstalling can reset the app's Keychain state depending on signing/team/access-group changes. If a device key is lost, remove its old device record in Admin before activating again if the License device limit is reached.
- The project uses an enterprise/ESign workflow in some cases. Test the exact signed IPA, not just an Xcode development build.

## API signature format
UTF-8 message signed by the Secure Enclave key:
`challenge + LF + action + LF + deviceId + LF + licenseKey`

`action` is exactly `register` or `verify`. The Worker imports the 65-byte uncompressed P-256 public key and verifies a 64-byte raw ECDSA signature. Challenges are random, bound to device and action, expire after 180 seconds, and can be consumed only once.
