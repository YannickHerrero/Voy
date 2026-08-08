# TestFlight release

Voy uses an App Store Connect API key stored outside the repository and a named App Store provisioning profile managed by Fastlane. The setup lane creates the app identifier, enables iCloud and push notifications, creates and associates the private CloudKit container, and creates the App Store Connect app record when needed.

1. Copy `.env.example` to `.env` and set the API key ID, issuer ID, and Apple ID.
2. Store the private key at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` with mode `600` (or set `ASC_KEY_PATH`). Fastlane uses the Apple ID only for Developer Portal configuration and reuses credentials from the macOS keychain and its private local session.
3. Build and upload from the repository root:

   ```sh
   fastlane ios beta
   ```

The lane chooses the next TestFlight build number without modifying tracked project files, archives the universal iPhone/iPad app, exports it with the production CloudKit environment, uploads the IPA, and waits for App Store Connect processing.

Run individual stages when diagnosing signing or upload issues:

```sh
fastlane ios setup
fastlane ios signing
fastlane ios build
fastlane ios upload
```

Before testers rely on synchronization, initialize the SwiftData schema in the development CloudKit environment and deploy that schema to production in CloudKit Console. A successful TestFlight upload does not deploy CloudKit record types automatically.
