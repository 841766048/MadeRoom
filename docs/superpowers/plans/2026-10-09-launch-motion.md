# Pixso launch animation integration

Source: Pixso Cvv6xQS2eeP0vnHU4qCbww, page 7:85, frames 7:6 / 7:24 / 7:42 / 7:62. Native UIKit only.

1. Reuse vector yarn renderer without its network ring or looping animation. Add a standalone launch controller matching 393 × 852 design geometry, cream background, rise/tilt/settle/wordmark sequence over 1.6 seconds.
2. Hold authentication routing until launch completion; resolve the current Firebase user at completion, preserving reinstall reset and consent logic. Finish immediately on background/interruption and use a short fade for Reduce Motion. Never replay on foreground resume.
3. Match the system static launch background to cream. Run unit tests for one-shot completion and background handling, build the workspace, and inspect native rendered output.
