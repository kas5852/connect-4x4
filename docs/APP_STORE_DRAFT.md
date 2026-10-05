# TestFlight and App Store draft

Prepared for the owner to review. No TestFlight invitation or App Store submission has been created. Live Game Center must be registered and checked with two different accounts before releasing the online feature.

| Field | Proposed value |
| --- | --- |
| Name | Connect 4x4 |
| Subtitle | Four boards. Beat the clock. |
| Platform / language | iOS / English (US) |
| Bundle identifier | io.github.kas5852.Connect4x4 |
| SKU | connect4x4-ios-2026 |
| Category / game genres | Games / Board, Strategy |
| Price | Free |
| Support URL | https://github.com/kas5852/connect-4x4/issues |
| Privacy policy URL | https://github.com/kas5852/connect-4x4/blob/main/docs/PRIVACY.md |
| Keywords | connect,four,board,strategy,timer,multiplayer,quick,challenge |

## Description draft

Four boards. One brain. How much chaos can you handle?

Play one to four games of Connect Four at the same time, each with its own turn clock. Connect four pieces to win a board. Win the most boards to take the match.

Miss a deadline? Autopilot drops a random legal piece. Choose a short clock for a frantic rush, or give yourself a little more thinking time.

Practice against a quick computer opponent, share a device for local two-player games, or challenge a friend through Game Center. Expand a board when you want larger controls, and rotate your phone for a landscape overview.

No ads or in-app purchases. Open source under the MIT license.

## What to test

Try one through four boards, each clock preset, Solo and Local play, focused controls, portrait and landscape, and a complete match followed by a rematch. Watch that human and computer pieces remain visible after landing. In Online mode, check a live match with two different Game Center accounts, deadline moves on both phones, rematches, and disconnect messages.

## Distribution steps

After signing into the owner's Karim Sabar team in App Store Connect, create the matching app record and enable Game Center. Prepare and upload a distribution archive, then complete the beta's contact information and export-compliance questions. The owner supplies their review contact details and personally handles account agreements.

For the wife to test remotely, create an external TestFlight group, select the uploaded build, and submit its first beta for Apple's review. After approval, create an invitation link for the owner to share; the wife installs Apple's TestFlight app and opens that link. No invitation email is sent by this project setup.

For public distribution, finalize the screenshots, age-rating and privacy answers, price and availability, and review notes, then submit the app to App Review. The six simulator UI checks and signed development installation do not establish that the live service is ready.

Privacy answers should reflect the actual implementation and Apple's definitions, including its [guidance on gameplay content, device-local data, and Apple-managed services](https://developer.apple.com/app-store/app-privacy-details/). This draft does not pre-fill a blanket “Data Not Collected” answer. See [the privacy policy](PRIVACY.md) and [the verification record](VERIFICATION.md).

Apple's [external TestFlight guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) and [submission guide](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/) describe the distribution flows.
