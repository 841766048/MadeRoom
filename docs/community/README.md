# Made Room community editorial — 2026-10-10

Added ten English Made Room Studio editorial examples to Community → For you → Studio inspiration. Each has a distinct existing remote illustration, its own detail page, materials, three adaptation ideas, a closing note and native text sharing. Original two demonstration cards remain.

These are explicitly labelled editorial examples, not user submissions. Text is bundled in `content/community-editorial.json`; images use existing Firebase Hosting URLs and the existing verified image loader. No new Firestore collection or publishing service was introduced. Images are illustrative and are not claimed to document real completed projects.

## Contents

- A softer home for everyday clutter (`studio-basket-reset`; image `search-baskets`)
- A quiet place at the table (`studio-quiet-place-setting`; image `search-placemats`)
- One shelf, a little breathing room (`studio-shelf-pause`; image `make-shelf`)
- A single vase, a slower corner (`studio-vase-still-life`; image `creator-vase`)
- One cushion changes the corner (`studio-soft-seat`; image `make-pillow`)
- A little room for flowers (`studio-little-flower-pause`; image `make-flowers`)
- Ten quiet minutes of running stitch (`studio-running-stitch-pause`; image `craft-embroidery-running-stitch`)
- An outline worth slowing down for (`studio-outlined-leaf`; image `craft-embroidery-split-outline`)
- A small square of steady progress (`studio-first-crochet-square`; image `craft-crochet-single-crochet`)
- Keep a tiny knitting journal (`studio-swatch-journal`; image `craft-knitting-gauge-swatch`)

## Verification

- Simulator build succeeded with Xcode 27 and the CocoaPods workspace.
- All 15 NavigationTests passed, including opening each of the ten posts, matching its title and ID, and returning to the original feed.
- All ten distinct remote images passed MIME and SHA-256 verification; see `image-verification.json`.
- Built app contains the exact community JSON source.
- No full screenshot-based visual acceptance was performed.

The initial navigation check exposed a mismatch with the app’s disabled-animation/reduced-motion policy. Detail navigation now follows the same policy as AppCoordinator.


## Unified detail layout — 2026-10-10

All C03 community details now use one shared `buildCommunityPost` renderer following the approved existing layout: Made Room navigation bar, 1.02-ratio cover, title, avatar/author row, body, interaction row, context cards and pinned View tutorial / Try this make buttons. The ten editorial cards also use the original feed card proportions. Materials and steps are shown after opening View tutorial.

Editorial actions keep the current post ID: local likes and saved collections are independent, sharing uses the current text, and creating a project carries its own materials and steps. Editorial comments are explicitly unavailable instead of opening an unrelated knowledge discussion. No fabricated authors, dates or community engagement counts were added.

Validation: all 16 NavigationTests passed, including all ten detail compositions, fixed actions, independent navigation, tutorial content, local likes and project creation. The built simulator app uses the CocoaPods workspace.

Layout snapshot: `unified-detail.png` verifies the shared content composition and corrected pinned actions. It is a layer-rendered XCTest snapshot; system navigation glass is not faithfully captured by this renderer. Final result: `Test-MadeRoom-2026.10.10_16-36-21-+0800.xcresult`, 16 tests passed.
