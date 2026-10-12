# Pixso account flow implementation plan

Goal: implement approved Pixso nodes 2:7, 2:39, 2:77 and 2:104 in UIKit.
Architecture: a dedicated account controller uses native stack layouts, text fields and actions; a separate consent controller persists only an explicit acceptance. Existing local tabs remain accessible. Auth services remain unavailable until configured.
Tech stack: Swift, UIKit, Auto Layout, XCTest, CocoaPods workspace.

- [x] Fetch Pixso code, screenshots and independent artwork; keep HTML outside app target.
- [x] Run registration UI test against old implementation and confirm missing account controls.
- [x] Add AuthViewController.swift and AuthPrivacyController.swift, with native gradients and localized copy.
- [x] Connect A01/A02, account settings and first-launch privacy; preserve local browsing after decline.
- [x] Run registration, privacy, reset and keyboard tests; build via MadeRoom.xcworkspace.
- [x] Inspect simulator captures against all four Pixso screenshots and record limitations.

Validation command: xcodebuild -workspace MadeRoom.xcworkspace -scheme MadeRoom -destination 'platform=iOS Simulator,id=CD567493-645A-46D1-8E80-C4A17441AEAC' -derivedDataPath build -only-testing:MadeRoomUITests/AuthFlowUITests CODE_SIGNING_ALLOWED=NO test
