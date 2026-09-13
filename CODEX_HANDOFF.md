# Mac Fold — Codex Handoff

**Repository root:** `/Users/Yatin/Documents/GitHub/Mac-Fold`  
**Canonical GitHub repository:** `https://github.com/satyalayatinasish-arch/Mac-Fold`  
**Current branch:** `main`  
**Latest release tag:** `v1.0.7`  
**Current app version:** `1.0.7` (Build `7`)  
**Last updated:** 2026-09-13 (local environment date)  

---

## 1. PROJECT OVERVIEW AND CORE GOAL

Mac Fold is a macOS menu-bar application for compatible Apple Silicon / modern MacBooks equipped with an internal lid angle sensor. When the physical MacBook lid closes below **90°**, Mac Fold projects a live, hardware-accelerated Metal perspective "fold" overlay onto the built-in display. The visual illusion keeps the display content appearing spatially upright and folding in perspective in real time as the lid closes.

### Key Rules & Invariants:
- **Strict 90° threshold**: At or above 90°, no fold overlay is active (`hysteresis = 0.0`).
- **Velocity-gated trigger**: The effect triggers during deliberate downward closing motion (closing velocity >= 2 deg/s). A stationary lid held below 90° will **not** spontaneously activate.
- **Built-in display only**: ScreenCaptureKit captures `NSScreen.builtIn`, strictly excluding Mac Fold's own windows to prevent visual feedback recursion.
- **Return on opening**: When the lid is opened, the geometry smoothly eases back to flat and the overlay terminates at exactly 90°.
- **Single canonical source tree**: Located strictly at `/Users/Yatin/Documents/GitHub/Mac-Fold`. Swift Package Manager (`Package.swift`) packaged via `build.sh` into `build/Mac Fold.app`.

---

## 2. CHRONOLOGICAL CONVERSATION & IMPLEMENTATION HISTORY

### Phase 1: Handoff & Project Consolidation
1. **Repository cleanup**: Deleted obsolete `iPhoneDuo` root prototype and promoted the real Mac Fold codebase to repository root (commit `08d4f52`).
2. **Rebranding**: Rebranded user-visible strings from "Mac Duo" to "Mac Fold" (`local.yatin.mac-fold`), preserving legal attribution in `NOTICE` and `LICENSE`.
3. **App Icon**: Created thin MacBook side-profile vector illustration (`AppIcon.svg` & `AppIcon.icns`).
4. **Settings Window**: Added standard macOS Command-comma (`Command-,`) settings window alongside the menu bar popover (commit `1ab9a9d`).
5. **Release v1.0.3**: Built ad-hoc and release DMG, tagged and published `v1.0.3` on GitHub. Verified live internal HID sensor via `./build/lidprobe` (Report 7 streaming hundredths of a degree).

### Phase 2: UI Redesign & Menu Bar Popover Separation
User requested:
> *"make an icon like this which opens the settings besides the keyboard shortcut and also modify the settings pane showing a macbook at angle which is exactly at the angle we kept our macbook at and it angle should change with the macbooks angle and menu should be provided seperatly and ui should be minimal and include a buton for switching between dark and light mode and also an liquid glass button"*

Implemented & committed (commit `bac0a5c`):
1. **`Sources/MacFold/MenuBarView.swift`**:
   - A dedicated minimal menu bar popover separate from the full Settings window.
   - Header with animated `ThemeSwitchButton` and version tag.
   - Embedded `MacBookHingeView` displaying live angle.
   - Quick toggles for Depth Effect and Live Mirroring, plus compact Eye Height and Base Tilt sliders.
   - Prominent `LiquidGlassActionButton` ("Test Fold Effect").
   - `SettingsPillBar` at bottom with `[ Settings ]` (opens full window) and `[ Quit ]`.
2. **`Sources/MacFold/MacBookHingeView.swift`**:
   - SwiftUI `Canvas`-based side-profile MacBook illustration.
   - The lid pivots dynamically to match `controller.currentAngle`.
   - Visual states: Normal (green/silver), Fold Active (<90°: glowing amber/orange), live angle badge and status capsule.
   - Supports both full and `compact: true` modes (used in SettingsView).
3. **`Sources/MacFold/LiquidGlass.swift`**:
   - `LiquidGlassButtonStyle`: Frosted glass blur, specular gradient stroke, spring press response.
   - `PillButtonStyle`: Translucent pill button styling.
   - `SettingsPillBar`: Dual pill buttons matching user's design reference.
   - `ThemeSwitchButton`: Cycles System -> Dark -> Light with icon animation.
4. **`Sources/MacFold/Preferences.swift`**:
   - Added `appTheme` (`"system"`, `"dark"`, `"light"`), with computed `colorScheme: ColorScheme?`.
5. **`Sources/MacFold/StatusItemController.swift` & `AppDelegate.swift`**:
   - Wired `StatusItemController` to host `MenuBarView`.
   - Clicking `Settings` pill invokes `SettingsWindowController.showSettings()`.
6. **`Sources/MacFold/SettingsView.swift` & `SettingsWindowController.swift`**:
   - Integrated compact `MacBookHingeView`, theme switcher, liquid glass test button, and appearance picker.
   - Window dimensions updated to 380x620.

### Phase 3: View-Based Fold Effect
User requested:
> *"develop view based fold effect like consider the angle off the base the keyboard and trackpad to the ground and the viewers eye balls and then based on it animation dyanmically starts from the view angle of the observe so the observer can fell the effect better based on the position not just the hinge 90 degree angle"*

Implemented (commit `48cd5bb`):
1. `Preferences.swift`: Added `observerElevationAngle` (default 20.0°) and `baseTiltAngle` (default 0.0°).
2. `DepthOverlay.swift`: `DepthGeometry.corners()` accounts for base tilt and observer eye elevation.
3. `LidController.swift`: Passes both parameters to `DepthTuning`.
4. `MacBookHingeView.swift`: Displays observer eye line and sight-line angle.
5. `SettingsView.swift` & `MenuBarView.swift`: Compact and full sliders for Eye Height and Base Tilt.

### Phase 4: Camera Eye Tracking with Hinge Compensation & Update System (v1.0.5 - v1.0.7)
User requested:
> *"use the camera to detect the angle of the viewer and perfectly detect the angle of the keyboard part to the ground and also the display angle make the closing animation based on the user view point placement of the macbook... provide checklist for auto updating its self in the application... automatically detect the eye height based on my eye postion use the self camera of the macbook... provide the new release and also add the auto update check in the and an update button"*

Implemented (commits `5696c82`, `cb74eae`, `47bab3f`):
1. **`ViewerPositionTracker.swift`**:
   - On-device Vision face landmark detection (`VNDetectFaceLandmarksRequest`), extracting left and right eye points.
   - **Hinge-to-Camera Compensation**: The webcam is physically mounted in the lid and rotates with it. The tracker calculates room-relative camera elevation:
     `cameraWorldElevation = hingeAngle + baseTiltAngle - 90`
     and adds the optical eye offset `cameraOffset`. This prevents closing the lid from being misread as the observer ducking or moving their head!
   - Non-blocking camera start/stop using background `cameraQueue` to prevent main-thread hitching.
   - Strict privacy: camera frames are processed only in memory and never saved or transmitted.
2. **`UpdateController.swift`**:
   - Optional automatic daily GitHub release check.
   - "Check for Updates" and "Get Update" buttons in Settings and menu bar popover.
   - `AUTO_UPDATE_CHECKLIST.md` documenting Developer ID signing, notarization, and signed EdDSA appcast needed before silent in-place self-installation can be enabled.
3. **Release v1.0.7**:
   - Package DMG: `build/release/Mac-Fold-1.0.7.dmg`.
   - Verified SHA-256: `2936478e17347d6c9da919372a6de56b0a934a8a57034275df94b78cb92863a7`.
   - Published GitHub release: `https://github.com/satyalayatinasish-arch/Mac-Fold/releases/tag/v1.0.7`.

### Phase 5: Version Display in Settings, Bug Fixes & Polish
User requested:
> *"add the version of the app in the app settings and update the app and also do the bug fix and improvements to the app"*

Implemented:
1. **Version Display in Settings & Menu Bar**:
   - `SettingsView.swift`: Displays `Version %@` directly below the "Mac Fold" title in the header.
   - `SettingsView.swift`: Displays a dedicated `Current Version` row (`1.0.7 (7)`) in the Updates section.
   - `SettingsView.swift`: Subtle footer at bottom of settings pane: `Mac Fold v1.0.7 (7)`.
   - `MenuBarView.swift`: Elegant capsule version badge (`v1.0.7`) next to the app title in the popover header.
2. **Bug Fixes**:
   - Fixed `UpdateController.swift` User-Agent string interpolation (`"MacFold/(self.currentVersion)"` -> `"MacFold/\(self.currentVersion)"`).
   - Improved version string comparison in `UpdateController.swift` to cleanly strip any `v` or `V` prefix.
   - Fixed `AppDelegate.swift`: Clicking "Check for Updates…" from the macOS application menu now brings up the Settings window directly so the user sees progress and results immediately.
   - Optimized `ViewerPositionTracker.swift`: `session.startRunning()` and `session.stopRunning()` now execute asynchronously on `cameraQueue`, completely eliminating UI freezes when toggling camera tracking.
3. **Localization**:
   - Added `Current Version` and `Version %@` strings to `en.lproj` and `zh-Hans.lproj`.

### Phase 6: Repository Discoverability & Homebrew Cask Distribution
User requested:
> *"suggest any changes how could actually make this github repo used by many people"* -> *"yay do them"*

Implemented:
1. **GitHub Topics**:
   - Added discoverability tags via `gh repo edit`: `macos`, `swift`, `metal`, `screencapturekit`, `macbook`, `macbook-pro`, `macbook-air`, `apple-silicon`, `hid-sensor`, `menu-bar-app`, `open-source`.
2. **Homebrew Cask Formula (`Casks/mac-fold.rb`)**:
   - Created native Homebrew Cask pointing to release `1.0.7` DMG with verified SHA-256 hash.
   - Allows one-liner terminal installation: `brew install --cask satyalayatinasish-arch/mac-fold/mac-fold`.
3. **Hardware Compatibility Matrix in `README.md`**:
   - Documented exact Apple Silicon & Intel T2 model support with HID Report details.

---

## 3. COMPLETE CODEBASE ARCHITECTURE & DIRECTORY STRUCTURE

```text
/Users/Yatin/Documents/GitHub/Mac-Fold
├── .github/workflows/release.yml       CI: Xcode build, sign, notarize, release (macos-15)
├── Casks/
│   └── mac-fold.rb                     Homebrew Cask formula for brew install
├── Package.swift                       SwiftPM manifest (macOS 14, Swift v5 mode)
├── README.md                           User documentation, install guide, feature overview
├── CODEX_HANDOFF.md                    Comprehensive handoff document
├── AUTO_UPDATE_CHECKLIST.md            Guide for production in-place auto-updater setup
├── LICENSE                             Apache 2.0 license
├── NOTICE                              Upstream attribution (preserve)
├── SECURITY.md                         Project security and privacy policy
├── assets/
│   └── menu.png                        Dark mode UI screenshot in README
├── build.sh                            Canonical build, sign, bundle, and launch script
├── Resources/
│   ├── AppIcon.icns                    Mac Fold side-profile app icon
│   ├── AppIcon.svg                     Vector source of app icon
│   └── Info.plist                      Bundle ID local.yatin.mac-fold, version 1.0.7 (7)
├── Sources/
│   ├── LidAngleKit/
│   │   └── LidAngleSensor.swift        IOKit HID sensor reader (Apple vendor 0x05AC, usage 0x8A)
│   ├── lidprobe/
│   │   └── main.swift                  Diagnostic CLI tool for testing sensor readings
│   └── MacFold/
│       ├── MacFoldMain.swift           @main entry point
│       ├── AppDelegate.swift           App lifecycle, Cmd+, and Cmd+Q menus
│       ├── Preferences.swift           UserDefaults storage (threshold, theme, observer angles)
│       ├── StatusItemController.swift  NSStatusItem and NSPopover hosting MenuBarView
│       ├── MenuBarView.swift           Minimal popover: hinge view, quick toggles, version badge, liquid buttons
│       ├── MacBookHingeView.swift      Dynamic SwiftUI Canvas MacBook side profile
│       ├── LiquidGlass.swift           Liquid glass button styles, pill buttons, theme switcher
│       ├── SettingsView.swift          Full settings pane UI with version displays and controls
│       ├── SettingsWindowController.swift AppKit NSWindowController for Cmd+, settings
│       ├── SettingsLanguage.swift      Localization helper
│       ├── UpdateController.swift      Daily update checks, version comparison, release links
│       ├── ViewerPositionTracker.swift Camera eye-tracking via Vision with hinge compensation
│       ├── LidController.swift         Sensor polling, velocity calculation, 90° trigger/release
│       ├── DepthOverlay.swift          Overlay NSWindow, DepthGeometry projection, Metal host
│       ├── DepthRenderer.swift         Metal rendering pipeline, Gaussian pyramid, texture upload
│       ├── DepthShaders.swift          Embedded MSL vertex & fragment shaders (inverse homography)
│       ├── Homography.swift            Projective 3x3 matrix math (Heckbert quad-to-quad)
│       ├── BlurGradient.swift          Dynamic blur & dimming curves
│       ├── CriticallyDampedSpring.swift Spring physics smoothing sensor angle jitter
│       ├── ScreenStreamer.swift        ScreenCaptureKit live display stream (excludes Mac Fold)
│       ├── ScreenSnapshotter.swift     ScreenCaptureKit fallback/pre-warm single frames
│       ├── CapturedFrame.swift         Pixel buffer frame wrapper
│       ├── Diagnostics.swift           OSLog logging categories
│       └── Resources/
│           ├── en.lproj/Localizable.strings
│           └── zh-Hans.lproj/Localizable.strings
```

---

## 4. HARDWARE, BUILD & SENSOR GROUND TRUTH

- **Host Environment**: macOS (Darwin 25.x / arm64), Xcode 26.6 (build 17F113), Apple Swift 6.3.3.
- **Physical Sensor**: Verified working on this machine via `lidprobe`.
  - HID Report 7: Hundredths of a degree precision (`0.01°`).
  - HID Report 1: Whole degree fallback.
  - Typical open angle: ~130°–135°. Fully shut: 0°.
- **Sandbox Notes**:
  - `swift build` and `./build.sh` touch `/var/folders/` caches; always run outside restrictive sandbox (`BypassSandbox: true`).
- **Build Commands**:
  ```bash
  cd /Users/Yatin/Documents/GitHub/Mac-Fold
  ./build.sh          # Build & ad-hoc sign Mac Fold.app and lidprobe
  ./build.sh --run    # Build, kill existing process, launch fresh app
  ./build/lidprobe    # Probe live lid sensor
  ```
- **Packaging Command**:
  ```bash
  mkdir -p build/release
  stage_dir=$(mktemp -d /private/tmp/mac-fold-1.0.7-dmg.XXXXXX)
  ditto 'build/Mac Fold.app' "$stage_dir/Mac Fold.app"
  ln -s /Applications "$stage_dir/Applications"
  hdiutil create -volname 'Mac Fold' -srcfolder "$stage_dir" -fs HFS+ -format UDZO 'build/release/Mac-Fold-1.0.7.dmg' -ov
  hdiutil verify 'build/release/Mac-Fold-1.0.7.dmg'
  rm -rf "$stage_dir"
  ```

---

## 5. RECENT COMMITS ON MAIN

- `df9a070 Display app version in Settings and MenuBar, fix update controller bug, optimize camera queue`
- `47bab3f Add hinge-compensated camera eye tracking and bump to 1.0.7`
- `cb74eae Add automatic eye tracking and update checks`
- `5696c82 Add camera-assisted viewpoint calibration`
- `c52f241 Add observer controls to menu bar popover`
- `89937e9 Update handoff for observer-perspective implementation`
- `48cd5bb Implement observer-perspective fold geometry`
- `bac0a5c Add minimal menu bar UI, MacBook angle viz, liquid glass controls, and theme switcher`
