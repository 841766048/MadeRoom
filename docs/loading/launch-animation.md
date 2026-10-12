# Native launch animation

Implemented from Pixso file Cvv6xQS2eeP0vnHU4qCbww, Play Launch page 7:85, frames 7:6, 7:24, 7:42, 7:62. Exported reference resides in design/launch/pixso-export outside the app target.

LaunchAnimationController renders a UIKit vector mascot with Auto Layout and transform/opacity keyframes: 450 ms rise, 350 ms gentle tilt, 400 ms settle, 400 ms wordmark reveal. No web view, video asset or screenshot rendering. The existing yarn vector is reused without its loading ring or continuous animation. The system launch storyboard uses the same cream background.

AppCoordinator defers Firebase routing during the animation, then reads the current authenticated user. Logged-out users still receive consent/login. Returning authenticated users receive their own main tabs. Background interruption and Reduce Motion setting changes finish once; Reduce Motion uses a 150 ms fade. Foreground resume does not recreate the controller.

Verified: full 41-test unit suite, AuthFlowUITests/testMainRouteCannotBypassLoginAfterConsent, and native final-frame attachments at 393×852 and 320×568. Final initial-pose adjustment separately reruns LaunchAnimationTests.
