# Gontacts

A SwiftUI contacts app for iPhone, iPad and iPhone Duo that talks straight to Google Contacts (People API), with birthday and anniversary reminders. It exists because Apple Contacts mangles year-less dates when saving to Google: Apple writes `1604-11-26` plus `X-APPLE-OMIT-YEAR=1604`, Google writes `--1126`. Gontacts reads and writes Google's own format (`{month, day}` with no `year`), and treats a `1604`/`0` year as "no year".

## Build

Requires Xcode 27 (iOS 26+ deployment target, Liquid Glass APIs).

```bash
brew install xcodegen          # once
xcodegen generate              # creates Gontacts.xcodeproj from project.yml
open Gontacts.xcodeproj
```

If `xcodebuild` complains the active developer directory is Command Line Tools, prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Run tests: `xcodebuild -scheme Gontacts -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

## Google sign-in

1. In Google Cloud Console, enable the **People API** and create an OAuth client of type **iOS** with bundle ID `xyz.saltedchips.gontacts`.
2. Create `Config/Secrets.xcconfig` (git-ignored):
   ```
   GOOGLE_CLIENT_ID = 1234567890-abcdef.apps.googleusercontent.com
   ```
3. Re-run `xcodegen generate` and build.

Without a client ID the app still runs: "Use Sample Contacts" on the connect screen loads demo data whose dates are relative to today (so there is always a birthday today, with confetti).

## Layout

- `Gontacts/Models`: `EventDate` (year optional), `Contact`, `EventTimeline` (Yesterday / Today / Tomorrow / This week / months), `SampleData`
- `Gontacts/Services`: `GoogleAuth` (OAuth + PKCE, Keychain), `PeopleAPI`, `ContactsStore`, `ReminderScheduler` (local notifications), `ReminderSettings`
- `Gontacts/Views`: Onboarding, Contacts, Contact detail (+ `ConfettiView`), Edit, Events, Wish, Settings
- `GontactsTests`: date round-trip and timeline tests

## Not done yet

- Incremental sync (`syncToken`); every sync is a full fetch
- Real app icon
- Testing on the iPhone Duo simulator (no Duo runtime installed here); layouts use `NavigationSplitView`/`TabView` so they adapt, but fold-aware tweaks (`ReservedRegion`) are untested
- Photos are display-only (no upload)
