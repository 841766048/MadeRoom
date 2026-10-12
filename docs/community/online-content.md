# Online content loading

The app no longer packages or reads `ios/content`. That directory is retained as publication source and test fixtures for the trusted publishing tools.

- Craft Library reads authenticated `knowledge` documents from the server. Initial load has no bundled article fallback; errors offer pull-to-refresh and an empty result is shown explicitly.
- Community and saved editorial posts use CommunitySync server snapshots. Project cover resolution uses that same catalog. Missing saved posts no longer receive a made-up local content card.
- Editorial image IDs resolve through `https://made-room-20261009.web.app/catalog/image-manifest.json`. Concurrent requests share one fetch. The app validates the image host, validates downloaded image hashes and retains normal HTTP/image caching. Failed loads can be tapped to retry. Small bundled authentication graphics remain separate UI assets.
- The Hosting predeploy script publishes only verified image IDs, hashes and URLs, without local source paths. The manifest has a five-minute cache policy; immutable image assets retain their existing long-lived caching.
- Comment pages no longer read or display `comments-seed.json`. They display online comments and the current account's persisted comments/outbox, including pending or failed sends.
- Legal pages continue to load their online documents through WKWebView.

Both project.yml and the Xcode resource build phase exclude content. Tests read publication fixtures from the repository explicitly; application code has no such readers. Do not delete publication source files while their publishing tools and fixture-based tests still require them.

Verification (2026-10-10): 58 unit tests passed, including package exclusion and manifest validation. The native UI flow passed online community comment publishing/reloading and server-only Craft Library loading with no content folder in the app. Production Hosting returned all 87 verified image records, and the downloaded room-hero image matched its published SHA-256. UI data writes used the emulator.
