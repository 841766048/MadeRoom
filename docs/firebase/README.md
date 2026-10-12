# Made Room — Spark integration

Project: `made-room-20261009` (display name: Made Room).
Apple app: `1:696279410418:ios:06878ad8e13856c1a8d26b`, bundle `studio.maderoom.ios`.
Billing remains disabled. No Blaze upgrade, Cloud Storage bucket, paid database, or Cloud Functions was provisioned.

## Content

- `content/knowledge-existing.json`: 8 structured existing editorial records and an archive of original English copy with source-file references. Ideas without a full tutorial remain marked as ideas.
- `content/knowledge-new.json`: 6 original English learning summaries covering weaving, embroidery and air-dry clay, with source URLs. Existing editorial images are contextual illustrations, not photographs of the new instructions. Embroidery lessons are text-only rather than using mismatched pictures.
- `content/comments-seed.json`: 5 demonstration comments, separate from knowledge. They are explicitly marked as demo content; no fabricated Auth UID or precise timestamp is assigned.
- `content/image-manifest.json`: stable image IDs, SHA-256 hashes, knowledge relationships and immutable Firebase Hosting URLs.
- UIKit Craft Library loads both knowledge files as an offline fallback, then refreshes from Firestore and displays English copy and source links. User-written text is preserved without silent translation.

Runtime comments are written to a separate JSON generation next to the user's state file. The state contains a pointer to that generation rather than comment text. The comment file is committed first, then the state pointer is atomically updated. Existing legacy comments migrate without losing their original text. Newly submitted comments synchronize to Cloud Firestore Standard in us-central1. Local JSON is retained as a per-account outbox. Legacy unowned local comments and demo fixtures are not silently uploaded under an invented identity.

## Images

78 public editorial PNG files were deployed to `https://made-room-20261009.web.app/editorial/`. Every downloaded file was checked against its original SHA-256 and MIME type before its local runtime copy and temporary upload copy were removed. The 4 login illustrations remain bundled. Original design documents and mockups are not runtime assets and were not deleted.

Views resolve remote images through the manifest, validate downloaded bytes, cache them, and offer retry on failure. A first visit without a network connection shows a placeholder rather than substituting an unrelated image.

For later deployments, the predeploy hook rebuilds the temporary Hosting folder from the verified public URLs. It never includes comments, user state or credentials:

```sh
npx -y firebase-tools@latest deploy --only hosting --project made-room-20261009
python3 tools/verify_hosted_images.py --remove-runtime-copies
```

Do not point Hosting at the entire workspace. The export script deliberately refuses to overwrite the established manifest.

## Accounts

Firebase email/password authentication is enabled. The app uses FirebaseAuth and FirebaseCore 12.19.0 through CocoaPods. Registration, sign-in, reset, session restoration and sign-out use the SDK. Only an authenticated session attaches the main interface. Account-specific local stores are separated by a SHA-256 of the Firebase UID; pre-account local files remain preserved and are not silently assigned to an arbitrary account.

Passwords are not written to app JSON. SDK-managed credentials use Keychain. Auth errors are shown without internal details, and reset responses do not expose whether an email exists. Comments synchronize in real time; other community publishing features remain disabled.

The Auth Emulator uses a separately named Firebase app and separate user-data directory. `--auth-emulator` is compiled only for Debug and points at loopback port 9098. It is not a login bypass.

## Verification

```sh
npx -y firebase-tools@latest emulators:start --only auth --project made-room-20261009
xcodebuild -workspace MadeRoom.xcworkspace -scheme MadeRoom \
  -destination 'platform=iOS Simulator,id=CD567493-645A-46D1-8E80-C4A17441AEAC' \
  -derivedDataPath build -only-testing:MadeRoomTests \
  -only-testing:MadeRoomUITests/AuthFlowUITests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Simulator ad-hoc signing is needed for Keychain; `CODE_SIGNING_ALLOWED=NO` is unsuitable for Firebase session tests. Production configuration is checked independently; UI tests use only emulator accounts. Delivery of a real password-reset email and physical-device autofill require follow-up testing.

Firebase MCP initially retained the previous project's context when registering the app. That accidental empty Made Room app registration was removed with the standard recovery period. The correct new-project registration and SDK configuration were verified; no original app or project data was deleted.

## Verified result — 2026-10-09

29 unit tests and 4 Auth UI tests passed (`Test-MadeRoom-2026.10.09_10-27-14-+0800.xcresult`). The expanded registration → restore → sign-out → wrong-password rejection → sign-in flow also passed (`Test-MadeRoom-2026.10.09_10-30-54-+0800.xcresult`). Production rejects invalid credentials as expected without creating a test account. All 78 hosted assets (2,410,904 bytes total) passed SHA-256 verification. English JSON and every article-image relationship passed validation.


## Realtime comments — 2026-10-09

The `(default)` Firestore database is STANDARD, located in `us-central1`, with `freeTier: true` and billing disabled. No extra database, PITR or backup billing features were enabled.

Documents live at `knowledge/{knowledgeID}/comments/{commentID}`. Fields are `knowledgeID`, `authorUID`, `authorName`, `text`, nullable `parentID` and `replyTo`, and server `createdAt`. Emails and passwords are not stored in comments. Readers must be signed in. Only the authenticated author can create a comment; editing and deleting are not exposed, and rules deny content/ownership changes and deletion. Unchanged retries are safe.

The app commits a stable UUID to the separate local comment JSON before transmission. An online transaction reads that UUID and only creates it if missing, preserving the original server timestamp on retry. Offline items remain pending; reconnecting, foregrounding or Retry resumes them. Rejected items show a failed state. A send is marked Synced only after server acknowledgement or receipt in a server-backed feed.

The current page listens to the latest 50 comments, supports loading older pages, and removes the listener when leaving. Switching accounts stops the prior sync owner and uses that account's local outbox. Live updates rebuild the feed without replacing the input field or discarding its draft. All 14 knowledge detail pages provide a Comments entry. Demonstration discussion is labelled separately and is never uploaded as real user activity.

Security Rules are a prototype: they enforce authentication, ownership, immutable content, allowed knowledge IDs, bounded strings, strict fields, server timestamps, root reply references and bounded queries. Review them before broadly sharing the app; they do not provide moderation or per-user anti-spam rate limits.

### Reproduce rule checks

```sh
# Use Java 21+ for the Firestore Emulator.
npx -y firebase-tools@latest emulators:start --only auth,firestore --project made-room-20261009
npm ci --prefix tools/firestore-tests
npm test --prefix tools/firestore-tests
```

The rule suite tests denied unauthenticated access, forged identity, unknown knowledge, oversized/mistyped/omitted/extra fields, timestamps, update/deletion, invalid parents, excessive queries, private paths, idempotent retries and cross-client realtime delivery. Tests use the local emulator only. Debug network switches exist only when both `--uitesting` and `--auth-emulator` are present.

BoringSSL-GRPC uses the exact upstream commit from its official CocoaPods spec, downloaded as a SHA-256-pinned archive to avoid cloning the entire Git history. Its source and checksum are in `tools/podspecs/BoringSSL-GRPC.podspec.json`.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for authenticated knowledge discussions by checking author ownership, allowed fields, bounded content, server timestamps, valid reply targets and query limits. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.

### Realtime verification result

All 21 Firestore rules/integration checks, 29 iOS unit tests and 4 authentication UI tests passed with zero failures. The UI flow additionally verified a second client’s live comment, draft preservation during updates, offline pending state and successful reconnection. Result bundle: `build/Logs/Test/Test-MadeRoom-2026.10.09_11-45-58-+0800.xcresult`. Production Firestore rules and indexes were deployed successfully; client write/read tests used emulator accounts rather than production users.


## Cloud knowledge — 2026-10-09

All 14 English knowledge records (8 existing, 6 new) are published to `knowledge/{id}` in the existing STANDARD `(default)` database in `us-central1`. The upload preserves every JSON field, including materials, steps, tips, sources, and image IDs, and adds `catalogOrder` and `schemaVersion`. Existing comment subcollections are preserved. Local JSON remains the editorial source and bundled offline fallback.

Craft Library fetches an ordered, bounded cloud query on opening and supports pull-to-refresh. On network failure it retains the displayed content and shows an offline/retry message. The cloud metadata and content are decoded with FirebaseFirestore Codable. Signed-in users can read knowledge; client writes, changes and deletion are denied. Publication uses the existing Firebase CLI administrator login without exporting or storing credentials.

To republish after editing the JSON, run `FIREBASE_TOOLS_DIR=/path/to/node_modules/firebase-tools node tools/publish_knowledge.cjs`. Add `--verify-only` for read-only comparison. The tool checks the project database's edition, region and free tier, validates unique article IDs and image mappings, commits the parent documents, then reads each document back and compares all fields.

Production verification: 14/14 documents matched the JSON sources after publication. Rules deployed successfully. All 22 emulator rules/integration tests passed, including signed-in bounded knowledge reads, denied anonymous reads and denied client publication/edit/deletion. Spark/free tier is unchanged; no paid services were added.

The updated app passed an iOS Simulator build with Xcode 27 (arm64 and x86_64). The initial validation used `IPHONEOS_DEPLOYMENT_TARGET=17.0` as a command-line workaround. The Podfile now includes a persistent post-install hook that raises older dependency deployment targets to the app's iOS 17 minimum, so normal builds no longer need that override. Validation used `CODE_SIGNING_ALLOWED=NO`; this was a compile check, not a new production-account UI test.


## Ten additional lessons — 2026-10-09

The library now contains 24 English records: 8 existing records and 16 newly researched lessons. The latest batch adds satin fill, split-stitch outlines, crochet chains, single crochet, slip stitch, knitting gauge, yarn weight symbols, clay drying, crack prevention and paint testing. Each lesson includes materials, actionable steps, tips and a source link. The three clay lessons reference the existing hosted pottery illustration; the other seven are explicitly text-only to avoid mismatched technique images. Image-manifest reverse associations have been updated.

All 24 Firestore documents were read back and matched the local JSON after publication. All 23 security/integration tests passed, including comment creation for every published knowledge ID. The existing region and free-tier database are unchanged. Open Craft Library or pull to refresh to retrieve the new records.

## Installation session and private profile — 2026-10-09

A non-backed-up app-container installation marker gates Firebase session restoration. A missing marker causes a synchronous Firebase sign-out and consent reset before any auth listener or main tabs are attached. Sign-out failure blocks startup instead of falling through to a retained Keychain user. Ordinary process restarts keep the session. The first update introducing the marker also requires one manual sign-in. Uninstalling does not delete the Firebase account or cloud records.

`users/{uid}` holds the owner's `displayName`, `username`, `biography`, private `location`, optional `avatar` bytes, `revision`, and server `updatedAt`. Only that authenticated UID may get or write the document; collection listing, other-user reads and deletion are denied. Username validation is format-only, not a global uniqueness claim. Comments retain the author's name at submission time.

Avatar uploads are JPEG thumbnails up to 256 pixels on the longest side and 96 KiB. This uses the existing free-tier Firestore database without enabling Cloud Storage or billing. The avatar is private profile data, not a public Hosting asset. Other selected project photos remain local.

Edits persist a pending revision in the account's local JSON before submission. Firestore queues offline writes; the UI shows pending status until acknowledgement. Foregrounding and Retry resume pending work. Remote profiles restore after manual login; local pending edits take precedence over incoming snapshots. Editing screens update only sync status so live snapshots do not discard draft input. Sign-out stops the old listener, and delayed callbacks verify the UID.

Tests cover missing/reused installation markers, failed sign-out, persistent profile outbox, avatar size, private-profile permissions, invalid schema/identity/timestamps, and oversized content. The emulator-only UI test simulates removal of installation and per-user local state, requires consent and manual sign-in again, and verifies the cloud name is restored. The simulation flag is guarded by DEBUG, --uitesting and --auth-emulator and cannot delete production profile caches.

Verified: 25 Firebase rules/integration tests and 33 iOS unit tests passed. All five AuthFlow UI scenarios passed, including the reinstall/profile-restore scenario. After refining sync-status placement, that scenario passed again. Unit result: `Test-MadeRoom-2026.10.09_16-22-58-+0800.xcresult`; final profile UI result: `Test-MadeRoom-2026.10.09_16-24-07-+0800.xcresult`. Production rules are deployed; profile creation/restoration tests used emulator accounts, not real production user data.
