# Online circle membership

Scope: membership only, using the existing STANDARD `(default)` database in `us-central1` with free tier enabled. User profiles, spaces, knowledge and comment paths remain unchanged. Challenge participation remains a separate local feature.

Each account owns `users/{uid}/circles/{circleID}` with exactly `uid`, `circleID`, `joined` and server `updatedAt`. Allowed circles are `craft`, `small-spaces`, `weaving`. Reads require the owner; collection queries are limited to 10. Both create and update validate the full schema; deletion is denied and leaving writes `joined: false`.

The app queries only its current account and uses an online transaction for membership changes. No automatic migration of local interests. UI does not optimistically claim membership and supports retry. Server snapshots restore membership on a new session; listeners stop on account changes. No member-count or public-member-list feature is introduced.

## Verification

- 37 emulator rules/integration tests passed, including owner-only membership reads/writes, bounded queries, strict schema, server timestamps and separate circle IDs.
- All 53 iOS unit tests passed, including no optimistic membership, failed join/leave preservation and fresh session state.
- Simulator UI test passed: join, clear the test installation/local account state, sign in again and restore from the server, leave, rejoin, and sign in with a second account to verify isolation.
- UI result: `build/Logs/Test/Test-MadeRoom-2026.10.10_17-31-10-+0800.xcresult`. Screenshots are under `screenshots`.
- Database inspection confirmed STANDARD, us-central1, freeTier true. No database or paid service was created.
- UI writes used isolated emulator accounts, not production user data.

Production rules deployment completed successfully to `made-room-20261009` on 2026-10-10. The CLI compiled, uploaded and released `firestore.rules`.
