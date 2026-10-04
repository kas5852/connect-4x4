# Verification record

Application source: [`dc060dd`](https://github.com/kas5852/connect-4x4/commit/dc060dd). Checks completed October 4, 2026. Later documentation-only commits do not change the tested application.

The automated engine and offline gameplay checks passed in both environments below. Live Game Center matchmaking between signed devices is still pending Apple account/app configuration and has **not** been verified. This is a development preview, not a production readiness claim.

| Check | GitHub Actions | Local Mac |
| --- | --- | --- |
| Toolchain | Xcode 16.4, macOS 15 runner | Xcode 27.0 (27A266a), macOS 26.6.2 |
| Core XCTest suite | 20 passed, 0 failed | 20 passed, 0 failed |
| Simulator UI XCTest suite | 5 passed, 0 failed, 0 skipped | 5 passed, 0 failed, 0 skipped |
| Simulator | iPhone 16 Pro, iOS 18.5 | iPhone 18 Pro, iOS 27.0 |
| Release build for physical iOS | Passed, unsigned | Passed, unsigned |

[Successful CI run and downloadable evidence](https://github.com/kas5852/connect-4x4/actions/runs/37237207454) include the simulator app, `.xcresult`, screenshots, and a machine-readable test summary. Actions artifacts have a 14-day retention period. Committed screenshots remain in `docs/images`. Local logs and the iOS 27 result bundle are under the ignored `.build/local` directory and `.build/local-iOS27.xcresult`.

The core suite exercises gravity, full columns, all win directions, draws, finished-board locking, 10,000 randomized complete games, independent deadlines, timeout/input ties, bounded catch-up, offline save validation, and computer turn ownership. Online protocol tests serialize a full host/guest match and rematch, reject stale or wrong-player moves and replayed/malformed packets, and check clock skew and fractional timestamps. These protocol tests run without Apple's live service.

The five simulator UI tests cover a complete four-board match followed by results and rematch, choosing each board count from one through four, focused-board input, random timeout moves without input, the solo computer with independent boards, and landscape overview/focus. Screenshots show the actual native interface, including [four boards](images/ios-four-boards.png), [results](images/ios-results.png), [landscape](images/ios-landscape.png), and [landscape focus](images/ios-focus.png).

An optimized standalone engine smoke check completed 10,000 randomized games in about 0.09 seconds and 1,000 four-board catch-up sessions in about 0.12 seconds on this Mac. These timings measure engine work, not animation frame rate, network latency, or iPhone energy use.

Before distribution, finish [Apple configuration and the two-device acceptance check](ONLINE_SETUP.md). Real matchmaking/authentication, signing/provisioning, disconnect behavior through Apple's service, physical-device frame time and touch latency, energy use, and VoiceOver usability remain unverified. GamePigeon integration is not implemented.
