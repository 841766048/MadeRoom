# Network loading coverage

All explicit production network entry points use NetworkLoading.shared.begin(). Finish each returned ticket in completion paths, including failures and cancellations. Call begin on the main thread; finish is thread-safe and idempotent.

Covered: Authentication sign-in / registration / password reset; server knowledge fetch and refresh; editorial image HTTP downloads; initial profile snapshot and profile writes; initial comment snapshot, pagination, and post/retry transactions.

A shared window-level RequestLoadingView preserves the Pixso yarn mascot design. Concurrent requests keep separate tickets. Presentation starts after 250 ms. Each ticket expires visually after 30 seconds without changing the actual request or reporting success. While visible, the full-window overlay consumes touches, dismisses the keyboard, and confines VoiceOver focus. Controls become available again after the final active ticket finishes or expires. Existing error and pending-sync messages remain authoritative.

Snapshot subscriptions finish their initial ticket on a server snapshot or error; cached snapshots retain it until server response or visual expiry. Live pushes after initialization are not new foreground loading operations. Listener removal and sync stop finish their owned tickets. Local image cache hits and Firebase signOut (a local session operation) do not create a request ticket. Firebase-internal token refresh/transport traffic is managed by the SDK, not treated as a separate user operation.

Validation: full MadeRoomTests suite plus concurrent ticket, duplicate completion, visual expiry, ticket deallocation, delayed-presentation cancellation and replacement tests.
