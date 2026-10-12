# Private Spaces sync

Project: made-room-20261009, existing Standard `(default)` database in us-central1; no billing or Storage enabled.

Path: users/{uid}/spaces/{stableSpaceID}. Fields: uid, name, notes, piecesJSON, planJSON, beforePhoto, afterPhoto, deleted, revision, updatedAt (server timestamp). Before/after photos are private JPEG blobs up to 192 KiB each, resized to a maximum 768 px edge. Names up to 80 characters, notes up to 4,000; piece payload up to 100,000 UTF-8 bytes. Photo/payload fields are exempt from indexing.

RoomStore persists per-space revisions before sending. Rename retains identity. Deletion writes a tombstone to prevent resurrection from stale local caches. Existing meaningful local spaces are migrated before cloud hydration; untouched default spaces wait for the server snapshot. Pending local changes win over older cloud snapshots; successful callbacks clear only their matching revision, so newer edits are not lost. Concurrent edits to the same space on different devices remain last-server-write-wins. Moving a piece between spaces involves separate per-space writes, so intermediate snapshots may temporarily differ.

The listener restores names, notes, optimized photos, plan checklist and placed project records. Project photo galleries are not part of this Spaces payload. Local originals remain on device; restored photos use the optimized cloud version. Failures remain visibly pending and retryable. All reads/writes use the shared Loading; no simulated remote success.

Owner-only read/list/create/update; strict field/type/size checks; server timestamp required. Direct delete is denied. Test rules cover owner access, isolation, malformed input, oversized photos, updates and tombstones.
