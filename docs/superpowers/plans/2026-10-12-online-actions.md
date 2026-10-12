# Complete online actions

1. Protect local-only clearing: stop sync services, sign out, reset without producing outbox records. Regression: no space/library deletion is queued.
2. Add per-record private library synchronization for projects, each compressed photo, saved items, collections and preferences. Persist revisions/outbox, hydrate before migration, preserve pending changes, use tombstones and isolate users. Start after space hydration and prevent legacy space snapshots resurrecting project records.
3. Add server-confirmed report/appeal submissions, block lists, challenge membership/submission/withdrawal and reaction state/counts. Preserve target context throughout menus and retries.
4. Add server-validated inbox events for follows, comments and reactions, read state and synced in-app notification preferences. User confirmed no APNs configuration; system pushes are outside this implementation.
5. Replace old service placeholders with live status/retry routes; show sync failures truthfully. Validate rules (cross-account, spoofing, private targets, atomic event proofs), unit regressions, native flows and production deployment.

Use existing Auth/Firestore infrastructure, existing billing tier, UIKit and CocoaPods. Do not fake moderation results or push delivery.
