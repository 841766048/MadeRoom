# Profile thumbnail galleries

Approved reference: design-works.png and design-spaces.png.

P01 now uses a compact cover and identity header, the existing live social counts, and two-column galleries. Works use square photos, project names and actual completion/progress. Spaces use 4:3 covers, names, actual piece counts and their private visibility. The latest readable project photo is used; a space prefers its after photo and falls back to its before photo. Missing or unreadable photos use a camera placeholder. No sample projects or room photographs are inserted into account data.

Each entire tile opens the corresponding project or space. The section plus buttons open project/space creation. An odd final item retains one column's width. Empty accounts receive a clear empty state. Changes from space synchronization refresh the profile gallery.

NavigationTests.testProfileThumbnailGridUsesRealPhotosAndRoutes checks 320/402-point widths, square/4:3 ratios, equal columns, real photo decoding, unreadable photo fallback, missing-photo placeholders and navigation/creation actions. Test attachments use a solid green fixture photo solely to verify the real local-image path; it is not shipped as user content.

## Missing-cover optimization

No-photo tiles now show an explicitly labeled illustrative cover instead of an empty camera tile. Project source-post images take priority among illustrations; otherwise known craft-category assets are selected. Room previews use known room/entryway illustrations. User photos still take priority. Bundled auth-mug/auth-room images provide immediate/offline visual fallbacks while the authenticated-image-manifest asset loads. Gallery image loading does not open a global touch-blocking loading overlay. Counts and account contents are not changed. Tests additionally verify source-cover resolution, valid asset references and immediately available preview images.
