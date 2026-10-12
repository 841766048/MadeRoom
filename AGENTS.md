# Made Room iOS project rules

- Implement the app with Swift + UIKit. Do not introduce SwiftUI or web containers.
- Manage all third-party dependencies through CocoaPods (`Podfile` / `Podfile.lock`). Do not introduce Swift Package Manager dependencies or a Package.swift manifest.
- Open and build `MadeRoom.xcworkspace`.
- `project.yml` is the XcodeGen source of truth. After regenerating the project, run `pod install` to restore integration.
- Core tests belong to the Xcode `MadeRoomTests` target; UI tests belong to `MadeRoomUITests`.
- The user has no backend and prioritizes local functionality and fidelity to the approved source designs. Never simulate remote success.
- Do not reintroduce screenshot-driven UI. No OCR coordinate playback, traced screenshot surfaces, or cropped UI controls. Author all screen structure and controls in UIKit with Auto Layout.
- Only audited independent content illustrations/photos/material images may live in EditorialAssets. legacy-screenshot-renderer is archival and must never be included in app targets.
- Screen launch coverage is not 1:1 visual acceptance. Verify each page against the approved source before claiming fidelity.

- Bottom Tab icons use the authored TabIcons.xcassets vectors (canonical P01 reference), with explicit normal/selected assets. Do not substitute approximate SF Symbols. Rebuild their SVG/PDF sources with tools/generate_tab_icons.swift.
