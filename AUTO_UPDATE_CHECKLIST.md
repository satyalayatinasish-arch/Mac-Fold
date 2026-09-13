# Mac Fold Auto-Update Checklist

Mac Fold currently checks the public GitHub release feed automatically when enabled and can open a verified release for the user. It does **not** yet replace itself. A safe macOS updater must not be added to an ad-hoc-signed app or pointed at arbitrary GitHub downloads. Complete every item below before enabling in-place installation.

## Required foundation

- [ ] Enroll in the Apple Developer Program.
- [ ] Configure a stable Developer ID Application certificate and Team ID.
- [ ] Configure App Sandbox / hardened-runtime entitlements only after testing the capture and camera permissions with them.
- [ ] Build universal `arm64` + `x86_64` releases.
- [ ] Sign the app and DMG with Developer ID, timestamp them, notarize them, and staple the tickets.
- [ ] Verify the downloaded app on a clean Mac with `spctl -a -vv` and `codesign --verify --strict --deep`.

## Update framework and feed

- [ ] Add a maintained native macOS update framework such as Sparkle through Swift Package Manager.
- [ ] Add the updater’s required `SUFeedURL` and public EdDSA key to `Resources/Info.plist`.
- [ ] Create a stable HTTPS appcast feed under a domain/repository path you control.
- [ ] Sign every update archive with Sparkle’s EdDSA private key; keep that key outside Git and CI logs.
- [ ] Include the version, build number, release notes URL, enclosure length, SHA/signature, and minimum macOS version in every feed item.
- [ ] Ensure the installer/updater can replace an app installed in `/Applications` and gives a clear error if the user runs from a read-only DMG.

## Product behavior

- [ ] Add a user-visible **Automatically check for updates** toggle, defaulting to off until the feed is proven.
- [ ] Add a **Check for Updates…** menu item and a settings status row showing the installed version and last check.
- [ ] Never download/install in the background without an explicit user confirmation.
- [ ] Pause update activity while the fold overlay/camera tracking is active and close the app cleanly before installation.
- [ ] Provide release notes and a manual DMG download link as a fallback.

## Release verification

- [ ] Test upgrade from the immediately preceding public version and an older version.
- [ ] Test a failed download, invalid signature, unavailable network, revoked/notarization failure, and insufficient disk space.
- [ ] Verify UserDefaults preferences, Screen Recording permission behavior, and camera permission behavior survive an update where macOS permits it.
- [ ] Confirm the update feed cannot downgrade the user or install an archive signed by a different key.
- [ ] Publish only after testing on both Apple Silicon and Intel hardware.

Until this checklist is complete, continue distributing versioned DMGs from GitHub Releases. That is the honest and safe delivery path for the current app.
