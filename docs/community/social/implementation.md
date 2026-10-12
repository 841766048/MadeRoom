# Real community relationships

Implemented 2026-10-10 for Made Room's existing UIKit app.

## Data and UI

- `publicProfiles/{uid}` holds display name, biography, approved avatar asset and example-account marker. Email, location and private profile image bytes never enter this collection. Editing the account's name/bio syncs its public presentation.
- `socialFollows/{followerUID}:{followingUID}` represents one actual relationship. Only the follower can create/delete it; self-follow, missing profiles, ownership changes and timestamp fabrication are denied. No new account automatically follows anyone. Legacy local follow sets are ignored.
- Personal and creator counts/lists derive from authenticated server snapshots of these relationships. Unconfirmed/cached relationship data displays an unknown state instead of claiming success; duplicate taps are disabled while the transaction runs. Listeners are removed on sign-out/account change. Transactions require connectivity.
- Community feeds read `communityPosts`, ordered by catalogOrder, at most 100 posts. The Following segment filters by actual followed author IDs. Author links, author post lists, saved post reopening and the approved shared detail layout use the same post model.
- New profiles start with neutral Member identity and no fictional portrait, work grid or social notifications. Makes counts use the account's actual project list.

## Example community

Five disabled editorial Auth identities are linked to five explicitly marked public example profiles: Nora Lane (weaving), Elena Cruz (vessels/flowers), Lily Tran (small spaces), Tessa Kim (stitching), Priya Shah (yarn practice). They have no email/password login credentials. Their ten English example posts reuse the project's approved hosted illustrations. These are illustrative editorial accounts, not claimed organic users.

`content/community-seed.json` is the source of the five profiles and ten posts. The publisher verifies every image reference and checks the existing database remains STANDARD/freeTier. It imports only missing scoped example identities without overwriting accounts, publishes only the named profiles/posts, reads them back, and creates no relationships or popularity metrics.

Run `FIREBASE_TOOLS_DIR=<installed firebase-tools package> node tools/publish_community.cjs --publish` to publish and verify. Omit `--publish` for read-only verification. Add `--emulator` for localhost Auth 9098 and Firestore 8188. Credentials remain in memory and are not written to project files.

## Limits

Community post publishing is still controlled by editorial tooling; the existing user draft workflow is unchanged. Hearts remain private local preferences, with no fabricated public like totals. Public community profiles show a neutral asset for regular members; private uploaded avatar bytes are not exposed. Relationships currently use per-profile live queries; larger deployments should add paginated lists and server aggregates before high-volume use. The feed is capped at 100 posts.

## Verification

Rules emulator checks cover zero initial relationships, follow/unfollow, duplicate and spoofed writes, self-follow, missing targets, privacy boundaries, protected example identities and controlled content publication. UIKit end-to-end coverage signs in fresh accounts, checks zero social counts, follows an actual example author, restores the relation after clearing local state, unfollows and checks account isolation.

Verified results: 41 security-rule tests, 53 iOS unit tests and the account-isolation UI flow passed. The UI flow also verifies that a separately authenticated member's follow creates a live follower count, persists after reinstall, and leaves the unrelated second account at zero. Production rules were released and all 5 Auth identities, 5 public profiles and 10 post documents were read back successfully. Screenshot: `screenshots/online-following-restored.png`.
