# Online actions and account restoration

## Implemented
- Private per-account library records sync projects (including projects without a space), compressed project photos, saved items, collections and notification/preferences data. Durable pending writes and revision checks preserve unsent changes. Deletes use tombstones.
- Existing space data hydrates before one-time library migration. Once migrated, legacy space snapshots cannot recreate deleted projects.
- Clearing local data stops sync, signs out and clears the local store without queuing cloud deletions. Unsynced edits are explicitly disclosed in the confirmation.
- Likes and counts read real reaction documents. Reports/review requests persist with submitted status. Blocking persists per account and filters posts, comments and creator lists.
- Challenge membership, submissions and withdrawal persist online, including a server-confirmed receipt.
- In-app notifications cover follows, comments/replies, likes and challenge receipts, with read state and synchronized preferences. APNs/system notifications are intentionally not configured, as requested.
- Inbox writes are validated against their source action in the same atomic operation; clients cannot forge moderation outcomes or another user's private data.

## Data locations
- `users/{uid}/library/{record}`: private library records and photo bytes.
- `users/{uid}/blocks/{targetUID}`: block state.
- `users/{uid}/inbox/{eventID}`: latest 100 in-app events displayed, deterministic event IDs and read state.
- `reports/{requestID}`: private requests; client status remains submitted until an authorized moderation process updates it.
- `users/{uid}/challenges/one-shelf`: membership.
- `challenges/one-shelf/submissions/{uid}`: private submission and withdrawal state.
- Target document `/likes/{uid}`: one reaction per account.

## Validation
- 51 Firestore rules tests pass, including cross-account access, forged notifications, private targets, blocking, reports and challenge ownership.
- 63 native unit tests pass, including local clearing without cloud deletion and library restoration/tombstones/legacy migration.
- Production rules and index deployment completed successfully.
- Four native UI flows pass: editorial comments/reload and real likes; private/public publication and reinstall; real social counts/account isolation and incoming notification navigation; project creation, local clearing and reinstall restoration.
- Final unit/UI run: `/tmp/maderoom-actions-library-final.log`; social inbox flow: `/tmp/maderoom-actions-restoration3.log`; publication/comments: `/tmp/maderoom-actions-ui.log`. The earlier library UI attempt used the populated-state button ID on a new empty account; the test selector was corrected and its final run passed.

## Operational boundaries
Notifications are generated for new operations; historical interactions are not backfilled. No device push delivery is claimed. Report submission is real, but this change does not create an administrative moderation dashboard or automatic review decisions. Each project photo is compressed to the existing 192 KiB cap. Library records resolve simultaneous edits per record; offline changes stay queued until the server accepts them.
