# Voy

Voy is a private, offline-first inventory, minimalism, and trip-packing app for iPhone and iPad. It is built entirely with native Apple frameworks and targets iOS 18 or later.

## Features

- Photo-first inventory with search, categories, collections, quantities, weights, and lifecycle statuses
- Camera and Photos library import with resizing, thumbnails, and optional Vision foreground extraction
- In-app `WKWebView` product browser with retailer-agnostic image discovery and source attribution
- Reusable packing templates and independent trip sessions with progress and weight totals
- Historical packing snapshots that remain useful when inventory items later change
- Minimalism dashboard with goals, category drill-down, nomadic-life comparison, and inventory history
- SwiftData persistence with private CloudKit sync and a local offline fallback
- Adaptive iPhone tab bar and iPad sidebar-style tab navigation, including light and dark appearances

## Requirements

- Xcode 16 or later
- iOS 18 SDK or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project
- An Apple Developer account with iCloud and push-notification capabilities for device sync

## Setup

1. Generate the Xcode project:

   ```sh
   xcodegen generate
   ```

2. Open `Voy.xcodeproj`.
3. In **Signing & Capabilities**, select your development team for the Voy target.
4. Ensure the app identifier and iCloud container are available to that team:
   - `com.yannickherrero.voy`
   - `iCloud.com.yannickherrero.voy`
5. Build and run. The app remains usable on-device if iCloud is temporarily unavailable.

Before distributing a production build, deploy the CloudKit development schema to production in CloudKit Console. User data is stored in each user's private CloudKit database.

## Verification

Run the unit test suite on an available simulator:

```sh
xcodebuild test \
  -project Voy.xcodeproj \
  -scheme Voy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

The tests cover schema bootstrapping, inventory and packing calculations, session independence, historical snapshots, inventory history, image processing, and web-image filtering.

Debug builds also support deterministic visual checks:

```sh
xcrun simctl launch booted com.yannickherrero.voy \
  -UseLocalStore -SampleData -InitialTab inventory
```

`-UseLocalStore` creates an in-memory store and skips CloudKit checks. `-SampleData` adds a 128-item library and representative packing/minimalism data. `-InitialTab` accepts `inventory`, `packing`, or `minimalism`. These flags and fixtures are compiled only for debug workflows.
