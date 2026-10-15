# Release plan: Play Store with ads

Goal: publish the Android version on Google Play as a free game with ads that can be removed
with a one-time purchase. The desktop version (Steam, optional) stays completely ad-free.

Status: planned, not started.

## Rules

| Topic | Decision |
|---|---|
| Ad format | Interstitial (full screen), only when a match ends naturally: after the result screen, on the way back to the lobby |
| Frequency | At most once every 2 matches, and at least 4 minutes after the previous ad |
| Host presses "End match" | No ad; only matches that end naturally count |
| No internet, or ad not loaded | Skip the ad silently; the game never waits for an ad |
| Player owns "Remove ads" | Never sees ads |
| Host owns "Remove ads" | Nobody in that host's room sees ads |
| Price | One-time "Remove ads", around 40 TL in Turkey; other countries via Play Console's local pricing |
| Desktop builds | No ad or billing code is included |
| Cosmetics (balls, skins, effects) | Not planned |

## Phase 0: Accounts (owner)

1. Create an AdMob account (linked to the Play developer account), add the app and create one
   Interstitial ad unit. Share the App ID and Ad unit ID.
2. In Play Console, create the app with package name `com.nightball.game`. The package name
   cannot change after the first upload.
3. Set up a payments (merchant) profile in Play Console; it is required for in-app products.

## Phase 1: Release key (together)

1. Create the release keystore. The owner chooses and types the password; it is never stored
   in the repository or in chat.
2. Back the keystore up in at least two places (for example a password manager and a USB drive).
3. Enable Play App Signing, so a lost upload key can be reset through Google.
4. Point Godot at the keystore through editor settings or environment variables, never through
   files in the repository.

Done when: a signed release AAB can be built.

## Phase 2: Android build setup

1. Switch the Android export preset to Gradle build (needed by the plugins) and install the
   Android build template.
2. Find and verify plugin versions compatible with Godot 4.7:
   - AdMob plugin
   - Google Play Billing (official Godot plugin)
3. Export an AAB for Play Store releases; keep exporting an APK for sharing with friends.
4. Make sure ad and billing code only runs on Android.

Done when: a debug APK with the plugins runs on a phone and plays exactly as before.

Risk: plugin compatibility with Godot 4.7 is the main unknown; verify it first.

## Phase 3: Ad manager

1. `Ads` autoload:
   - preloads the next interstitial at startup and after each ad;
   - on a natural match end, applies the frequency rule and shows the ad if one is ready;
   - skips ads when the player or the host owns "Remove ads".
2. Use Google's test ad unit IDs throughout development. Clicking real ads on your own app can
   get the AdMob account suspended.

Done when: on a phone, test ads appear after natural match ends at the expected interval, and
the game does not stall with internet turned off.

## Phase 4: "Watching an ad" sync

1. Protocol version 4: clients tell the host when an ad starts and ends.
2. The lobby shows 📺 next to players watching an ad. "Start game" stays disabled until everyone
   is back, for at most 45 seconds.
3. Tests for the ad state, the timeout and the premium-host case.

Done when: with two phones, the host cannot start while the other phone shows an ad.

## Phase 5: Remove ads purchase

1. Owner: create a one-time product `remove_ads` in Play Console.
2. A small "Remove ads" button in the menu with the purchase flow; restore purchases on new
   phones and reinstalls; hide the button once owned.
3. The host includes its premium flag in lobby packets; the lobby shows "Ad-free room ⭐".

Done when: buying with a Play test account removes ads, and a guest in a premium host's room
sees none.

## Phase 6: Consent and legal

1. Google UMP consent flow for regions that require it (EEA, UK); fall back to
   non-personalised ads when consent is refused.
2. Privacy policy: the game stores no personal data, ads are served by Google AdMob, purchases
   go through Google Play. Publish it on GitHub Pages.
3. Play Console forms (answers drafted together):
   - Data safety: advertising ID, device information, purchase history
   - "Contains ads"
   - Target audience: 13 and over (an audience that includes children brings the much stricter
     Families ad policy)
   - Content rating questionnaire

Note: the game itself collects nothing, but the AdMob SDK collects the advertising ID and device
data, which is why consent and a privacy policy are required once ads are added.

## Phase 7: Store listing and release

1. Screenshots at phone resolution (generated with `godot/tools/capture.gd`), a 512×512 icon and
   a 1024×500 feature graphic.
2. Short and full descriptions in Turkish and English.
3. Newer personal developer accounts may need a closed test with 12 testers for 14 days before
   production access; check whether this applies to the account.
4. Internal test → closed test → production.

Risks: the closed-test requirement can add two weeks; AdMob reviews new apps before serving
ads, which can take a few days.

## Phase 8: Steam (optional, later)

An ad-free, free desktop release. Needs a Steamworks account and the $100 app fee. Low priority;
itch.io is a free alternative.

## Order

0 → 1 → 2 → 3 → 4 → 5 → 6 → 7, with a phone test at the end of each phase from 2 to 6.
