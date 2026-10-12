# Online community publishing

The C02 composer, C13 draft editor and X05 retry action publish to `memberPosts` through the authenticated CommunitySync service. A transaction creates a stable draft ID once; unchanged retries read the same post. The app shows success only after a server read confirms the committed document, then clears that draft. Failed requests preserve the draft.

Public posts are readable by signed-in members. Private posts are visible only to their owner. Both appear in My posts; only public posts appear in the community feed. The author may delete a post online. Security rules reject forged authors, modified published documents, malformed content and unauthorized reads/deletes.

Titles support 1–120 characters, bodies 1–4000 characters including newlines. An optional photo uses the existing space-photo pipeline (JPEG, maximum 768px and 192KiB) and is stored without a searchable index. Each feed query loads the newest 50 posts. Reporting moderation and challenge submissions remain separate features.

Verification covers security rules, draft retry identity, legacy draft decoding, native publication and restoration after reinstall. Deployment uses the existing project and does not enable paid photo storage.

Verified on 2026-10-10: 56 iOS unit tests and 44 emulator rules tests passed. The native UI test passed private publication, restoration after simulated reinstall, public publication and feed display. Production security rules were deployed and both member-post composite indexes reported READY. Native end-to-end publishing tests ran against emulators; no test posts were published to production.


## Community comments

Editorial and member-post detail pages now open the existing online comment UI. Discussion keys are `community:<postID>` and `member:<postID>` under `knowledge/<discussionKey>/comments`. This preserves the existing persistent outbox, realtime updates, pagination, replies and retry behavior while isolating every post from knowledge articles and seed comments.

Rules require the source post to exist. Member-post discussions inherit public/owner-only visibility; deleting the post makes its comments inaccessible. Reply parents must belong to the same discussion. Multiline comments are accepted. The page uses the actual post title and cover.

Comment verification: 57 unit tests and 45 rules tests passed. The native UI test opens an editorial post, sends a comment, waits for server synchronization, leaves and reopens the discussion, and verifies the comment remains. Rules were deployed to production; UI writes were tested only in the emulator.
