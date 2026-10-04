# Run a live Game Center match

The online implementation is included in the iOS app. Apple's service requires an app identity and signing configuration before it can connect real accounts. The checked-in entitlement enables Game Center; it does not register an app with Apple by itself.

## Apple configuration

1. Install full Xcode 16 or later and add your Apple Developer account under Xcode Settings → Accounts.
2. Open `Connect4x4.xcodeproj`, choose the application target, and select your team under Signing & Capabilities. Use your own unique bundle identifier if the default is not registered to your team. If you change it, update `project.yml` before regenerating the project.
3. Enable the Game Center capability for that app identifier and confirm Game Center appears in Signing & Capabilities. The entitlement file is `App/Connect4x4.entitlements`.
4. Create an App Store Connect app record with exactly that bundle identifier and enable Game Center for the app. This game does not use leaderboards or achievements, so it does not require those resources.
5. Build the same app onto two iPhones/iPads. Sign into **different Game Center accounts** on the devices.

Apple's [real-time game sample](https://developer.apple.com/documentation/gamekit/creating-real-time-games) and [Game Center configuration guide](https://developer.apple.com/documentation/gamekit/initializing-and-configuring-game-center) describe the service setup. This is separate from publishing source to GitHub.

## Two-device acceptance check

1. Choose Online on both phones. Invite the other player through Game Center, or use automatch on both. Both apps should show the same board count and turn duration after connecting; the Coral player's setup wins if they selected different settings.
2. Confirm each device can play only its own color. Make moves on all four boards in different orders. Every piece and turn should match on both screens.
3. Let a timer expire. Exactly one host-chosen random legal move should appear on both phones, and only that board's timer should reset. Let multiple boards expire together.
4. Tap near expiry and tap repeatedly. There should be no double move, wrong-color move, or stale tap applied to a later turn.
5. Focus one board while playing another on the other phone. All clocks continue. Verify full columns reject input and winning boards stop.
6. Complete all boards. Both phones should agree on board wins and the match winner. Coral starts a rematch; both screens should reset to empty boards together.
7. Background either app or turn off its connection. Both players should return to setup with a connection/ended-match message rather than continuing different games. Try cancelling authentication and matchmaking, then start again.

The simulator CI checks the offline UI, compiles the iOS GameKit implementation, and exercises the real serialized state/intent protocol using an injected clock. It does not sign into two Game Center accounts or perform the above live service check. Device frame time, touch latency, energy use, VoiceOver behavior, and network latency should also be measured on signed builds.

## Match protocol

Both peers choose the host by lexicographically ordering the two game-scoped Game Center player IDs. The host is Coral and owns the rules engine, deadlines, randomness, scoring, and rematches. The guest is Gold and sends column intents with the board ID, match ID, and expected move count. The host checks ownership and uses receipt time to reject expired turns. A new snapshot acknowledges both successful and stale requests.

Reliable snapshots include a monotonically increasing revision and match UUID. The replica rejects old, foreign, malformed, or unsupported snapshots and validates each board by replaying its moves. The guest calibrates host clock offset using a ping and round-trip midpoint. The estimate cannot remove network delay; only the host resolves expiry. Inputs remain pending until an authoritative response arrives.

The first connection retries its readiness handshake for up to 15 seconds. A send failure, disconnect, or backgrounded app ends the match. There is no dedicated backend, reconnect, host migration, or competitive anti-cheat. Both players trust the elected host for this casual game.
