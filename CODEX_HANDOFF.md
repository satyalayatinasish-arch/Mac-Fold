# Mac Fold — Codex Handoff

**Repository root:** `/Users/Yatin/Documents/GitHub/Mac-Fold`  
**Canonical GitHub repository:** `https://github.com/satyalayatinasish-arch/Mac-Fold`  
**Current branch:** `main`  
**Verified local HEAD:** `12a22220165d8c10db3f6ea1d2511ae959c2e8ab` (`Add project handoff documentation`)  
**Current app version:** `1.0.3`  
**Prepared:** 2026-09-13 (local environment date)

This document is intentionally source-grounded. Statements marked **Uncertain** were not proven by a full live hardware/UI test in this session.

## 1. PROJECT GOAL AND OVERALL ARCHITECTURE

Mac Fold is a macOS menu-bar application for compatible MacBooks. It reads the physical lid/hinge angle and, while the lid closes below 90°, overlays the built-in display with a live Metal-rendered perspective/fold effect. The goal is to make screen content appear to remain spatially upright while the physical display lid folds downward.

Required behavior implemented in source:

- At and above the threshold (default **90°**), no fold overlay is active.
- During a deliberate close, the effect begins only after the lid angle drops below 90°.
- During opening, it returns to a flat representation and ends at exactly 90°.
- Above 90°, no animation/effect should be shown.
- The effect is for the **built-in display only** and uses live desktop content by default.

High-level data flow:

```text
Apple internal HID lid-angle sensor
  -> LidAngleKit/LidAngleSensor
  -> LidController (polling, velocity prediction, 90° trigger/release)
  -> ScreenCaptureKit / ScreenSnapshotter / ScreenStreamer
  -> DepthOverlay / DepthRenderer / Metal shaders
  -> click-through, non-key fullscreen-style overlay window on built-in display

Menu-bar popover + Cmd+, app menu
  -> SettingsView / Preferences (UserDefaults)
  -> LidController configuration and preview
```

The project is a Swift Package Manager macOS app, not an Xcode project. `build.sh` packages the SwiftPM executable and resource bundle as `Mac Fold.app`.

## 2. CURRENT IMPLEMENTATION AND EXACT CURRENT STATE

### Implemented and verified from source/build outputs

- The app is branded **Mac Fold** in the application bundle, Settings UI, menu bar accessibility description, app menu, README, and release packaging.
- `CFBundleIdentifier` is `local.yatin.mac-fold`.
- The app is a menu-bar app (`LSUIElement = true`) with no Dock icon by default.
- The standard application menu includes:
  - `Settings…` with the Command-comma shortcut.
  - `Quit Mac Fold` with Command-Q.
- The menu-bar button opens the same `SettingsView` in a popover.
- A dedicated `SettingsWindowController` opens a standard settings window for Command-comma.
- Settings include master enable, live rendering, timeout, trigger angle, blur/dimming/perspective controls, menu-bar angle, launch at login, language, reset, quit, and Screen Recording permission guidance.
- English and Simplified Chinese localization resources exist.
- Internal HID sensor support is implemented. It matches Apple vendor ID `0x05AC`, usage page `0x20`, usage `0x8A`, requires a built-in HID device, attempts report 7 (hundredths of a degree), then report 1 (whole degrees).
- Lid control uses both a low-rate idle poll and a higher active rate. It tracks closing velocity and predicts fast closures to reduce apparent sensor latency.
- The user’s requested exact threshold behavior is represented by `Preferences.hysteresis = 0` and default `thresholdAngle = 90.0`.
- ScreenCaptureKit mirrors the built-in display. The capture filter excludes Mac Fold’s own application windows to avoid overlay feedback.
- The overlay is borderless, ignores mouse events, cannot become key/main, and is configured to be visible across spaces.
- A static screenshot seed is available as fallback when the live stream has no frame yet. The default is live rendering.
- The app handles sleep/wake and display-layout changes by dismissing/reinitializing the effect/capture state.
- The app icon has both `Resources/AppIcon.svg` and `Resources/AppIcon.icns`. It is a thin side-profile MacBook/folding-lid illustration based on the user’s supplied reference image.
- The app builds successfully on this machine. The most recent inspected local app is ad-hoc signed and passed strict signature verification.
- A local DMG exists and had previously been validated with `hdiutil verify`:
  - `build/release/Mac-Fold-1.0.3.dmg`
  - SHA-256: `11927ae7d6701e0da247a21584da66743dc0db73cc560d5e734b837e67c075b2`

### Verified hardware sensor status
- **Verified: live hardware sensor communication.** Tested on this host machine using `./build/lidprobe`. Detected Apple internal HID sensor via report 7 with 0.01° precision, actively streaming live angles (~134.93° when open).
- **Pending physical gesture test:** A physical fold-down test past the 90° boundary while Screen Recording permission is active.
- **Uncertain: the current GitHub Actions workflow has not been run/inspected to completion in this session.** It requires Apple Developer signing/notarization secrets; runner updated to `macos-15`.
- **Uncertain: whether every MacBook model exposes report 7 or report 1 exactly as expected.** The code has report fallback, but compatibility depends on the particular hardware and macOS.

### Current unfinished work

There is no known uncommitted application feature work. The immediate pending task after this handoff is to test the deployed/current source on actual compatible hardware through the full 90° close/open scenario, then fix only observed defects. This handoff file itself is the only change created at the end of the prior session and must be committed if the user wants it stored in GitHub.

## 3. COMPLETE RELEVANT PROJECT / FILE STRUCTURE

The following is the relevant tracked source layout. Build outputs and `outputs/` are ignored and intentionally not source controlled.

```text
/Users/Yatin/Documents/GitHub/Mac-Fold
├── .github/workflows/release.yml       GitHub Actions signed/notarized development-release workflow
├── .vscode/launch.json                 Editor launch configuration
├── .zed/debug.json                     Zed debug configuration
├── .zed/tasks.json                     Zed task configuration
├── LICENSE                             Apache License 2.0 text; preserve
├── NOTICE                              Upstream Mac Duo attribution; preserve for legal compliance
├── Package.swift                       SwiftPM package definition (macOS 14, MacFold + lidprobe)
├── README.md                           User-facing app README
├── Resources/
│   ├── AppIcon.icns                    Bundled macOS icon; preserve
│   ├── AppIcon.svg                     Editable source icon; preserve
│   └── Info.plist                      App metadata/version/name/icon/LSUIElement
├── Sources/
│   ├── LidAngleKit/
│   │   └── LidAngleSensor.swift        HID-based internal hinge-angle reader
│   ├── MacFold/
│   │   ├── MacFoldMain.swift           @main entry point
│   │   ├── AppDelegate.swift           App lifecycle and application menu (Cmd+, Cmd+Q)
│   │   ├── LidController.swift         Core sensor state machine and overlay/capture lifecycle
│   │   ├── Preferences.swift           UserDefaults-backed app settings/defaults
│   │   ├── MenuBarView.swift           Minimal menu bar popover UI
│   │   ├── MacBookHingeView.swift      Live angle-accurate MacBook vector illustration
│   │   ├── LiquidGlass.swift           Liquid glass button styles, theme switcher & pill buttons
│   │   ├── SettingsView.swift          SwiftUI settings window UI
│   │   ├── SettingsWindowController.swift  Standard settings window used by Command-comma
│   │   ├── StatusItemController.swift  Menu-bar item and settings popover
│   │   ├── DepthOverlay.swift          Overlay window, perspective geometry, Metal host
│   │   ├── DepthRenderer.swift         Metal renderer and texture/frame upload
│   │   ├── DepthShaders.swift          Embedded Metal shader source
│   │   ├── ScreenStreamer.swift        ScreenCaptureKit live stream path
│   │   ├── ScreenSnapshotter.swift     ScreenCaptureKit single-frame/prewarm fallback
│   │   ├── CapturedFrame.swift         CVPixelBuffer/Metal captured-frame wrapper
│   │   ├── BlurGradient.swift          Per-frame blur gradient construction
│   │   ├── CriticallyDampedSpring.swift Smooth visual-angle spring
│   │   ├── Homography.swift            Perspective transform math
│   │   ├── Diagnostics.swift           OSLog categories/subsystem
│   │   ├── SettingsLanguage.swift      Language preference/localization lookup
│   │   └── Resources/
│   │       ├── en.lproj/Localizable.strings
│   │       └── zh-Hans.lproj/Localizable.strings
│   └── lidprobe/
│       └── main.swift                  CLI diagnostic for the lid sensor
├── assets/menu.png                     README menu/settings screenshot
├── build.sh                            SwiftPM build, app bundle packaging, signing, optional launch
├── mise.toml                           Tooling configuration (inspect before changing)
├── build/                              Ignored local build output (not tracked)
│   ├── Mac Fold.app                    Current locally built app
│   ├── lidprobe                        Current locally built diagnostic executable
│   └── release/Mac-Fold-1.0.3.dmg      Current local installer
├── outputs/                            Ignored local delivery copy
│   └── Mac Fold.app
└── work/LidAngleSensor/                Ignored local helper checkout; not Mac Fold source
```

Important history: the repository previously had an obsolete root `Sources/iPhoneDuo` prototype and the real app nested under `work/Mac-Fold`. Commit `08d4f52` removed the obsolete prototype from Git and promoted the real Mac Fold source to the repository root. Do **not** recreate or maintain a second project copy.

## 4. TECHNOLOGIES, FRAMEWORKS, DEPENDENCIES, AND VERSIONS

| Area | Verified implementation |
|---|---|
| Language | Swift; package manifest declares Swift tools `6.0`; targets deliberately use Swift language mode `.v5`. |
| Platform | macOS 14.0 minimum (`Package.swift`, `Resources/Info.plist`). |
| Build system | Swift Package Manager plus custom `build.sh`. |
| UI | AppKit (`NSApplication`, `NSWindow`, `NSStatusItem`, menus) and SwiftUI (`SettingsView`). |
| Graphics | Metal, CoreGraphics, QuartzCore, CoreVideo. |
| Capture | ScreenCaptureKit. |
| Sensor | IOKit / IOKit.hid HID feature reports. |
| Settings | `UserDefaults`, Combine, SwiftUI `@AppStorage`. |
| Login item | ServiceManagement `SMAppService.mainApp`. |
| Local toolchain inspected | Xcode `26.6`, build `17F113`; Apple Swift `6.3.3`; target `arm64-apple-macosx28.0`. |
| Package dependencies | No external Swift package dependencies are declared in `Package.swift`. |
| Version | `CFBundleShortVersionString = 1.0.3`; `CFBundleVersion = 1`. |

## 5. IMPORTANT USER REQUIREMENTS AND CONSTRAINTS

These requirements came from the user during this project and should be retained unless the user explicitly changes them:

1. The project must live and be maintained only at `/Users/Yatin/Documents/GitHub/Mac-Fold`.
2. The app name must be **Mac Fold** everywhere user-visible, replacing **Mac Duo**.
3. Remove user-visible `Made by Makito` and Makito copyright branding from the app/UI/metadata. Do **not** remove legally necessary upstream attribution in `NOTICE` or `LICENSE` without legal authority.
4. Use the Mac lid-angle sensor application / internal sensor for the actual lid angle.
5. The visual must act like a fold effect: the display’s content appears to remain around 90°/upright while the physical lid closes.
6. No visual effect is shown above 90°.
7. On closing, the effect begins only once the sensor angle is below 90°.
8. On opening, the effect stops at 90°.
9. Provide a normal macOS Settings pane/window accessible with Command-comma.
10. Build a Mac Fold app icon showing the MacBook side-on at an angle/folding, based on the supplied reference image.
11. Maintain one source codebase, not recurring duplicate project copies.
12. Stage/commit/push completed work to the GitHub `main` branch and create versioned releases/DMGs when requested.
13. The GitHub repository was requested to be public.
14. When usage is approaching a limit, inform the user proactively rather than only reporting a hard usage-limit stop.

## 6. DECISIONS ALREADY MADE AND WHY

### Canonical source-root consolidation

**Chosen:** The real app is at repository root, not under `work/Mac-Fold`.

**Why:** The old root iPhone Duo prototype was missing the actual effect, screen capture, Metal rendering, menu bar, settings, app packaging, and most Mac Fold features. Keeping it alongside the real project would force duplicate maintenance and violate the user’s request.

**Result:** Commit `08d4f52` moved the real Mac Fold files to root and deleted `Sources/iPhoneDuo` from Git. `work/LidAngleSensor` remains ignored only as a local helper checkout, not as application source.

### Exact 90° threshold

**Chosen:** `Preferences.thresholdAngle` defaults to `90.0`, and `Preferences.hysteresis` is fixed at `0`.

**Why:** The user explicitly asked for start below 90° during closing and stop at 90° during opening, without a visible effect above 90°.

### Live capture plus fallback

**Chosen:** Default `isLivePicture = true`, using `ScreenStreamer`; a screenshot/prewarm fallback is retained.

**Why:** The requested effect should show current desktop content while moving. A screenshot seed prevents an empty overlay on rapid triggering before the stream produces its first frame.

### AppKit app shell + SwiftUI settings

**Chosen:** AppKit manages lifecycle, menubar, and a standard settings window; SwiftUI supplies reusable settings content.

**Why:** This gives a conventional macOS menu and Command-comma behavior while sharing the same settings UI with the menu-bar popover.

### Ad-hoc local signing; CI for Developer ID/notarization

**Chosen:** `build.sh` ad-hoc signs by default. The GitHub Actions workflow is designed for Developer ID signing/notarization when secrets are configured.

**Why:** Local development must be possible without exposing or requiring Apple credentials. A public release intended for smooth Gatekeeper use must be signed/notarized using the dedicated secrets.

### Legal attribution retained

**Chosen:** `NOTICE` and `LICENSE` are retained, even though `NOTICE` says `Mac Duo` and `Copyright 2026 Makito`.

**Why:** It is required upstream attribution from the original Apache-licensed project. The user asked to remove user-facing author/copyright branding, not to strip legal notices. Do not casually alter/remove legal attribution.

## 7. IMPORTANT CODE AND CONFIGURATION DETAILS

### `Package.swift`

- Package name: `MacFold`.
- `platforms: [.macOS(.v14)]`.
- Targets:
  - `LidAngleKit` at `Sources/LidAngleKit`.
  - `MacFold` executable at `Sources/MacFold`, dependent on `LidAngleKit`, processing its `Resources` directory.
  - `lidprobe` executable at `Sources/lidprobe`, dependent on `LidAngleKit`.

### `Resources/Info.plist`

Verified important keys:

```xml
CFBundleDisplayName = Mac Fold
CFBundleName = Mac Fold
CFBundleExecutable = MacFold
CFBundleIdentifier = local.yatin.mac-fold
CFBundleShortVersionString = 1.0.3
CFBundleVersion = 1
LSMinimumSystemVersion = 14.0
LSUIElement = true
CFBundleIconFile = AppIcon
```

### `Sources/LidAngleKit/LidAngleSensor.swift`

- Finds Apple (`0x05AC`) HID devices on usage page `0x20`, usage `0x8A`.
- Skips candidates not marked built-in, preventing a same-usage external display from being selected.
- Tries feature report 7 (`[0x07, b0, b1, b2, b3]`, hundredths-of-degree) first, then feature report 1 (`[0x01, lo, hi]`, whole degrees).
- `angle()` returns `nil` on read/format/range failure and exposes `lastRead` for diagnostics.
- The source states angle `0` means closed and open is approximately 130°.

### `Sources/MacFold/LidController.swift`

This is the main behavior owner. Important facts:

- Published status: `currentAngle`, `isSensorAvailable`, `isActive`.
- Sensor polls at `1/8` second when idle and `1/30` second while near/within active range.
- `triggerClosingSpeed = 2` degrees/sec; only a recent downward movement can initiate the effect. A lid held already below threshold must not start the effect by itself.
- A prediction path accounts for quick-close sensor latency when velocity is less than `-40` degrees/sec.
- `wantsEffect(angle:)` starts below the threshold only on a recent close and releases at `angle >= threshold + hysteresis`; hysteresis is currently zero.
- Closing out eases the visual back to the exact threshold before fading/dismissing the overlay, avoiding an obvious brightness/geometry jump.
- `runPreview()` feeds a simulated angle sequence through the same control path. It is triggered by a distributed notification named `local.yatin.mac-fold.preview`; inspect UI wiring before changing.
- It prewarms capture/filter resources before activation, handles ScreenCaptureKit stream/screenshot states, and handles sleep/wake/display changes.

### `Sources/MacFold/Preferences.swift`

Defaults currently registered in `UserDefaults`:

```text
isEnabled = true
isTimeoutEnabled = false
thresholdAngle = 90.0
blurSpan = 60.0
maxBlurRadius = 135.0
maxDim = 1.0
viewingDistance = 6.0
recession = 1.0
blurEvenness = 0.0
dimReach = 0.5
showsAngleInMenuBar = false
isLivePicture = true
hysteresis = 0 (constant, not user setting)
```

Do not claim these settings are factory-clean in an already-used installation; old values persist in `UserDefaults` until the user presses Reset or relevant keys are removed.

### `Sources/MacFold/DepthOverlay.swift`, `DepthRenderer.swift`, `DepthShaders.swift`

- `DepthOverlay` owns a borderless click-through overlay window and a Metal host view.
- `DepthGeometry` turns the image about its bottom hinge edge; `currentAngle`, `startAngle`, eye distance, and recession shape the projection.
- `DepthRenderer` and `DepthShaders` provide the GPU path for perspective, blur, and dimming. Read all relevant rendering code before changing geometric behavior because the visuals are coupled to `DepthTuning` and controller angle progression.

### `Sources/MacFold/ScreenStreamer.swift` and `ScreenSnapshotter.swift`

- `ScreenStreamer` uses ScreenCaptureKit on `NSScreen.builtIn` and asks for 30 fps frames.
- It caches an `SCContentFilter`, excludes its own app windows, and rebuilds the filter when screen layout changes.
- `ScreenSnapshotter` supports a single capture and a prewarm capture path. It is used when stream startup is too slow or live rendering is disabled.

### `Sources/MacFold/AppDelegate.swift` and `SettingsWindowController.swift`

- `AppDelegate` initializes `Preferences`, `LidController`, `StatusItemController`, and `SettingsWindowController` at launch.
- It installs an explicit app menu with `Settings…` key equivalent `,` and `Quit Mac Fold` key equivalent `q`.
- `SettingsWindowController` creates `SettingsView` in a 400×590 AppKit window, minimum 400×420.

### `build.sh`

- Run from repository root.
- Builds `MacFold` and `lidprobe` in release mode.
- Copies the SwiftPM resource bundle, plist, icon, `LICENSE`, and `NOTICE` into `build/Mac Fold.app`.
- Default signing is ad-hoc (`SIGN_IDENTITY=-`).
- `--run` kills an existing `MacFold` process, then opens the rebuilt app.
- `--universal` requests both arm64 and x86_64 architectures.

### `.github/workflows/release.yml`

- Runs on pushes to `main` and workflow dispatch.
- Uses `macos-26`, latest stable Xcode action, universal build, Developer ID signing, notarization, DMG/ZIP construction, and GitHub release `dev` publication.
- Requires these GitHub secrets:
  - `APPLE_CERTIFICATE_P12_BASE64`
  - `APPLE_CERTIFICATE_PASSWORD`
  - `APPLE_TEAM_ID`
  - `APPLE_NOTARY_KEY_P8_BASE64`
  - `APPLE_NOTARY_KEY_ID`
  - `APPLE_NOTARY_ISSUER_ID`
- It publishes a moving prerelease tag `dev`, not a semantic tag. The manually created semantic `v1.0.3` GitHub release is separate.
- **Potential workflow concern to verify before relying on it:** The workflow assumes `macos-26` and the external `maxim-lobanov/setup-xcode@v1` action are available. This was inspected but not executed during this session.

## 8. SIGNIFICANT BUGS / ERRORS AND DEBUGGING HISTORY

### A. Xcode / SDK mismatch early in development

**Symptom:** The initial Swift build failed due to missing SDK/Command Line Tools mismatch (the exact original compiler output is not available in this verified repository state).

**Cause:** The active developer directory was not the complete/current Xcode toolchain.

**Resolution:** The user installed full Xcode and selected `/Applications/Xcode.app/Contents/Developer`. Later builds completed successfully.

**Do not assume resolved on a different machine:** Verify with `xcodebuild -version`, `xcode-select -p`, and `swift --version` before debugging app code.

### B. Swift concurrency compiler diagnostics around the timer / IOKit lifecycle

**Observed error text from earlier development notes:**

```text
capture of self with non-Sendable type...
sending self risks causing data races
```

**Cause:** Timer/Task closures and lifecycle cleanup conflicted with Swift’s stricter concurrency checking.

**Fix applied:** The controller was made `@MainActor`; closure boundaries use `MainActor.assumeIsolated`; IOKit/timer lifecycle handling was adjusted, including `nonisolated(unsafe)` where necessary in the earlier implementation.

**Current status:** Current source built successfully with Swift 6.3.3. Do not remove actor isolation casually.

### C. Moved-project Swift module cache failure

**Observed error text from earlier development notes (abridged):**

```text
precompiled file ... compiled with module cache path old ... current path new
```

and missing SwiftShims/cache symptoms.

**Cause:** Swift build cache was tied to the prior nested project path when the project directory was moved.

**Fix applied:** The old generated `.build` cache was moved out and the project rebuilt from the new path.

**Current status:** The fresh root-level build completed. If source is moved again, clear/move only the generated `.build` cache and rebuild; do not delete source.

### D. Packaging command rejected by execution safety policy

**Observed tool response:**

```text
Rejected("... rm -f style commands are not permitted. Use a safer approach")
```

**Cause:** A packaging command attempted `rm -f` of an existing DMG.

**Fix applied:** Existing delivery items were moved to a temporary recovery folder and packaging proceeded without destructive deletion.

**Current status:** `build/release/Mac-Fold-1.0.3.dmg` was created and validated.

### E. Initial DMG creation failure

**Observed error text:**

```text
hdiutil: create failed - No such file or directory
```

**Cause:** `build/release` did not exist at that point.

**Fix applied:** Created the release directory before running `hdiutil create`.

**Result:** DMG verification later reported:

```text
hdiutil: verify: checksum of "build/release/Mac-Fold-1.0.3.dmg" is VALID
```

### F. GitHub CLI release API transient failures/timeouts

**Observed responses:**

```text
HTTP 502: Server Error (https://api.github.com/repos/satyalayatinasish-arch/Mac-Fold/releases)
```

```text
HTTP 500 (https://api.github.com/repos/satyalayatinasish-arch/Mac-Fold/releases/387844296)
```

and GitHub CLI calls that returned after the local execution timeout without immediate output.

**What happened:** Despite the API errors/timeouts, direct release inspection later confirmed that the v1.0.3 asset uploaded and the release became public.

**Verified final release state:**

- Tag: `v1.0.3`
- Public release URL: `https://github.com/satyalayatinasish-arch/Mac-Fold/releases/tag/v1.0.3`
- Asset URL: `https://github.com/satyalayatinasish-arch/Mac-Fold/releases/download/v1.0.3/Mac-Fold-1.0.3.dmg`
- Asset SHA-256: `11927ae7d6701e0da247a21584da66743dc0db73cc560d5e734b837e67c075b2`

**Correct procedure on future releases:** After a timeout/error, inspect the actual release (`gh release view vX.Y.Z --json ...`) before retrying. Do not assume failure and create duplicate releases/assets.

### G. Git push looked incomplete due to timeout

**Symptom:** A push command timed out/returned before confirming all work.

**Resolution:** Remote refs were inspected directly with `git ls-remote`; the remote `main` did contain commit `08d4f52` and tag `v1.0.3` existed. Current verified status before creating this handoff was clean and tracking `origin/main`.

## 9. CRITICAL FILES THAT MUST BE PRESERVED

Do not modify these unnecessarily:

| File / directory | Why it is critical |
|---|---|
| `Package.swift` | Defines macOS deployment target and all executable targets. |
| `Sources/LidAngleKit/LidAngleSensor.swift` | Core hardware access. Changes can break sensor compatibility. |
| `Sources/MacFold/LidController.swift` | The 90° transition behavior, fast-close prediction, timeout, prewarm, and lifecycle are all here. |
| `Sources/MacFold/DepthOverlay.swift`, `DepthRenderer.swift`, `DepthShaders.swift` | Coupled geometry/rendering pipeline for the effect. |
| `Sources/MacFold/ScreenStreamer.swift`, `ScreenSnapshotter.swift` | Screen Recording/capture paths, self-exclusion logic, live fallback. |
| `Sources/MacFold/Preferences.swift` | User settings keys and default threshold semantics. Avoid breaking persisted settings. |
| `Resources/Info.plist` | App identity, name, version, menu-bar behavior, minimum OS. |
| `Resources/AppIcon.icns`, `Resources/AppIcon.svg` | Current delivered icon and editable source. |
| `LICENSE`, `NOTICE` | Legal/license compliance. Preserve. |
| `build.sh` | Canonical local app packaging method. |
| `.github/workflows/release.yml` | CI release pipeline; its secrets and notarization logic are sensitive. |

## 10. CURRENT NEXT STEP

1. Commit and push this `CODEX_HANDOFF.md` if it should be retained in the repository. Do not combine it with unrelated source changes.
2. On a compatible MacBook, run the current build and perform a real physical verification:
   - grant Screen Recording to the rebuilt app,
   - open the lid beyond 90° and confirm no overlay,
   - deliberately close through 90° and confirm overlay begins only below it,
   - move within the below-90° range and confirm live content/geometry responds smoothly,
   - reopen to 90° and confirm it lands flat then disappears at that threshold,
   - verify clicks pass through the overlay and normal UI continues to work.
3. If a defect is observed, capture the exact angle, expected behavior, actual behavior, app settings, and Console/OSLog output before changing code. The most likely first files to inspect are `LidController.swift`, `DepthOverlay.swift`, and `ScreenStreamer.swift`.
4. If a release build is needed after a code change, increase `CFBundleShortVersionString` consistently, build/verify locally, then create a semantic Git tag/release. Do not create version bumps merely for this documentation-only file unless the user asks.

## 11. COMMANDS AND PROCEDURES

Run commands from the canonical repository root:

```sh
cd /Users/Yatin/Documents/GitHub/Mac-Fold
```

### Inspect state

```sh
git status --short --branch
git log --oneline -8
git remote -v
```

Expected before adding this handoff file: `main...origin/main` with no modified/untracked files. After this file is created, it will appear as an untracked file until added/committed.

### Build and package local app

```sh
./build.sh
```

Expected result: `build/Mac Fold.app` and `build/lidprobe`, with output including `Build of product 'MacFold' complete!` and an ad-hoc signature check.

### Build then launch locally

```sh
./build.sh --run
```

Expected result: Any existing `MacFold` process is stopped and `build/Mac Fold.app` is opened. Screen Recording permission may need to be granted again after a rebuild because the app has an ad-hoc signature.

### Build universal local app

```sh
./build.sh --universal
lipo 'build/Mac Fold.app/Contents/MacOS/MacFold' -verify_arch arm64 x86_64
```

### Verify local bundle metadata/signing

```sh
plutil -p 'build/Mac Fold.app/Contents/Info.plist'
codesign --verify --strict --verbose=1 'build/Mac Fold.app'
codesign -dv 'build/Mac Fold.app' 2>&1 | rg 'Identifier|TeamIdentifier|Signature'
```

Expected local signature: `Identifier=local.yatin.mac-fold`, `Signature=adhoc`, `TeamIdentifier=not set` unless `SIGN_IDENTITY` was explicitly supplied.

### Run the sensor diagnostic

```sh
./build/lidprobe
```

**Uncertain:** Exact CLI output was not captured in this session. Inspect `Sources/lidprobe/main.swift` before interpreting output. On unsupported hardware it may report unavailable/no reading.

### Check GitHub releases

```sh
gh auth status
gh release view v1.0.3 --json tagName,isDraft,url,assets
```

### Commit the handoff only (if requested)

```sh
git add CODEX_HANDOFF.md
git commit -m 'Add project handoff documentation'
git push origin main
```

Do not run a broad `git add -A` until reviewing `git status`; it can unintentionally stage unrelated user work.

## 12. DO NOT REPEAT THESE MISTAKES / PITFALLS

1. **Do not work in `/Users/Yatin/Documents/ChatGPT/mac fold app`.** The user explicitly selected `/Users/Yatin/Documents/GitHub/Mac-Fold` as the sole canonical project path.
2. **Do not revive the obsolete `iPhoneDuo` project or create a second Mac Fold source tree.** The real source is at the repository root after commit `08d4f52`.
3. **Do not remove `LICENSE` or `NOTICE` just because they reference Mac Duo/Makito.** They are legal attribution. User-facing branding has already been changed.
4. **Do not change `hysteresis` above zero** unless the user changes their exact 90° requirement. Positive hysteresis causes the effect to remain active above 90° during opening.
5. **Do not make the effect trigger merely because the lid is resting below threshold.** `LidController` intentionally requires recent closing movement to avoid spontaneous activation.
6. **Do not remove the stream self-exclusion/presence-window mechanism.** It prevents the overlay from capturing itself recursively.
7. **Do not treat GitHub CLI timeout/HTTP 5xx as definitive failure.** Inspect the release and remote refs first; prior operations succeeded asynchronously.
8. **Do not delete broad directories or use destructive cleanup against the repository.** The prior path move was safely handled by moving generated files/caches to temporary recovery folders first.
9. **Do not assume a local ad-hoc app is notarized.** It is not. Only the secrets-backed GitHub Actions path is intended to sign/notarize a public release.
10. **Do not mutate UserDefaults keys/name defaults without migration consideration.** Existing installations preserve settings.
11. **Do not claim hardware behavior is verified without physically testing the hinge and Screen Recording path.** Compilation/signature success is not a real animation test.

## 13. VERIFICATION / TESTING CHECKLIST

### Static / build verification

- [ ] `git status --short --branch` has only intentional changes.
- [ ] `swift build -c release --product MacFold` succeeds.
- [ ] `swift build -c release --product lidprobe` succeeds.
- [ ] `./build.sh` succeeds.
- [ ] `codesign --verify --strict --verbose=1 'build/Mac Fold.app'` succeeds.
- [ ] `plutil -extract CFBundleShortVersionString raw 'build/Mac Fold.app/Contents/Info.plist'` matches `Resources/Info.plist`.
- [ ] Confirm `Resources/AppIcon.icns` is present in `build/Mac Fold.app/Contents/Resources/AppIcon.icns`.

### Functional hardware verification

- [ ] Run `build/Mac Fold.app` on a MacBook that exposes a supported lid-angle sensor.
- [ ] Open settings by pressing Command-comma; confirm a normal Mac Fold Settings window appears.
- [ ] Open menu-bar settings; confirm it displays `Mac Fold`, current angle, and all controls.
- [ ] Enable Screen Recording for the current rebuilt app in macOS Privacy & Security.
- [ ] With lid above 90°, confirm no visual effect is visible.
- [ ] Close deliberately past 90°; confirm effect begins only below 90°.
- [ ] Confirm the built-in display’s live desktop content is captured, perspective shifts smoothly, and the overlay does not recursively show itself.
- [ ] Confirm the effect responds to continued lid movement below 90°.
- [ ] Open the lid; confirm it returns flat and removes the overlay at 90°.
- [ ] Confirm clicks pass through the overlay.
- [ ] Toggle Live rendering off; confirm a held frame is used instead of live updates.
- [ ] Toggle timeout and hold the lid still below threshold; confirm it behaves as documented (ends after about two seconds of stillness).
- [ ] Put system to sleep/wake and change display arrangement; confirm no stuck overlay remains.

### Release verification

- [ ] Check the semantic tag points to the desired commit.
- [ ] Check GitHub release asset SHA-256 after upload.
- [ ] Mount the DMG on a clean/representative machine, drag the app to Applications, launch it, and confirm Gatekeeper/notarization behavior. This is required before claiming a release is user-ready.

## 14. GIT / WORKTREE / RELEASE STATE

### Verified before adding this handoff document

```text
Branch: main
HEAD: 12a2222 Add project handoff documentation
Tracking: origin/main
Status: clean
Remote: https://github.com/satyalayatinasish-arch/Mac-Fold.git
```

Local Git identity inspected:

```text
name: satyalayatinasish-arch
email: satyalayatinasish@gmail.com
```

Existing relevant commits:

```text
12a2222 Add project handoff documentation
08d4f52 Consolidate Mac Fold into repository root
bdecb9b Polish Mac Fold application menu
1ab9a9d Add Command-comma settings window
3bd41a5 Release Mac Fold 1.0.0 with side-profile icon
e52b849 Add Mac Fold side-view app icon
1909694 Rebrand application as Mac Fold
909cf64 Initial Mac Fold implementation
```

Semantic releases/tags created earlier include at least `v1.0.0`, `v1.0.1`, `v1.0.2`, and `v1.0.3`. The verified current public semantic release is v1.0.3.

### State after creating this document

`CODEX_HANDOFF.md` was added to tracking in commit `12a2222` and pushed to `origin/main`. Subsequently, `README.md` was significantly enhanced, CI runner modernized to `macos-15`, and the hardware sensor live stream was verified using `lidprobe`.

## 15. ENVIRONMENT-SPECIFIC DETAILS

- Canonical working directory: `/Users/Yatin/Documents/GitHub/Mac-Fold`.
- A previous extra clone/path may exist at `/Users/Yatin/Documents/ChatGPT/mac fold app`; do not use it for updates.
- Inspected machine toolchain: Xcode 26.6 (`17F113`), Apple Swift 6.3.3, arm64 host/target.
- Local GitHub CLI authentication was active for GitHub account `satyalayatinasish-arch` with `repo` scope when inspected. Authentication can expire/change in a new session; verify with `gh auth status`.
- `build/`, `outputs/`, `.build/`, `work/LidAngleSensor/`, and `.DS_Store` are ignored. They are local artifacts/helper files, not canonical source.
- The local `build/Mac Fold.app` is ad-hoc signed. Screen Recording may need to be re-authorized after rebuilding.
- Do not disclose or add credentials to the repository. The CI workflow expects GitHub repository secrets for Developer ID signing/notarization.

## CONTINUATION INSTRUCTION

Read this handoff first, then inspect `/Users/Yatin/Documents/GitHub/Mac-Fold` and its Git state to verify every relevant claim before acting. Preserve the single root-level Mac Fold implementation and the legal files. Continue from the documented current state by performing the real hardware 90° behavior verification (or the user’s next explicitly requested task), then make only evidence-based changes. Do not restart, redesign, recreate a duplicate project, or undo completed branding/root-consolidation work unless it is necessary to fix a verified issue.
