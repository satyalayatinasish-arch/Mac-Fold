# Mac Fold — Codex Handoff

**Repository root:** `/Users/Yatin/Documents/GitHub/Mac-Fold`  
**Canonical GitHub repository:** `https://github.com/satyalayatinasish-arch/Mac-Fold`  
**Current branch:** `main`  
**Latest implementation commit:** `48cd5bb` (`Implement observer-perspective fold geometry`)
**Current app version:** `1.0.7` (locally built, signed, and packaged)
**Last updated:** 2026-09-13 (local environment date)  

---

## 1. PROJECT OVERVIEW AND CORE GOAL

Mac Fold is a macOS menu-bar application for compatible Apple Silicon / modern MacBooks equipped with an internal lid angle sensor. When the physical MacBook lid closes below **90°**, Mac Fold projects a live, hardware-accelerated Metal perspective "fold" overlay onto the built-in display. The visual illusion keeps the display content appearing spatially upright and folding in perspective in real time as the lid closes.

### Key Rules & Behavior:
- **Strict 90° threshold**: At or above 90°, no fold overlay is active (`hysteresis = 0.0`).
- **Velocity-gated trigger**: The effect triggers during deliberate downward closing motion (closing velocity >= 2 deg/s). A stationary lid held below 90° will **not** spontaneously activate.
- **Built-in display only**: ScreenCaptureKit captures `NSScreen.builtIn`, strictly excluding Mac Fold's own windows to prevent feedback loops.
- **Return on opening**: When the lid is opened, the geometry smoothly eases back to flat and the overlay terminates at exactly 90°.
- **Single canonical source tree**: Located strictly at `/Users/Yatin/Documents/GitHub/Mac-Fold`. Swift Package Manager (`Package.swift`) packaged via `build.sh` into `build/Mac Fold.app`.

---

## 2. CONVERSATION & TASK HISTORY (CHRONOLOGICAL)

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
   - Header with animated `ThemeSwitchButton`.
   - Embedded `MacBookHingeView` displaying live angle.
   - Quick toggles for Depth Effect and Live Mirroring, plus compact Eye Height and Base Tilt sliders for the view-based perspective.
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
7. **Localizations & Assets**:
   - Updated `Localizable.strings` (en and zh-Hans).
   - Updated `assets/menu.png` with a dark mode screenshot (commit `ca79c8f`); the README no longer embeds it because it predates the observer controls and macOS screenshot permission was unavailable for a truthful replacement.
   - Modernized `.github/workflows/release.yml` runner from `macos-26` to `macos-15`.

### Phase 3: View-Based Fold Effect (In-Flight)
User requested:
> *"keep this in the menubar pop and donot distrub anything other and also develop view based fold effect like consider the angle off the base the keyboard and trackpad to the ground and the viewers eye balls and then based on it animation dyanmically starts from the view angle of the observe so the observer can fell the effect better based on the position not just the hinge 90 degree angle use every resource you have to develop this feature and update git and git hub by commiting all the necessary changes and also changes to the readme the pictures the dmg file for installation,etc."*

---

## 3. VIEW-BASED FOLD EFFECT SPECIFICATION & DESIGN

### Core Geometric Principle:
Currently, the depth warp in `DepthGeometry.corners()` only calculates projection based on the physical hinge travel from the threshold (`startAngle - currentAngle`).

The **View-Based Fold Effect** integrates the physical spatial relationship between:
1. **Base Plane (beta)**: Tilt angle of the MacBook keyboard/trackpad relative to horizontal desk surface (`baseTiltAngle`, default `0.0°`, range `0°–30°`).
2. **Display Lid Angle (theta)**: Current physical hinge angle (`currentAngle`, e.g. `90°` down to `0°`).
3. **Observer Eye Elevation (alpha)**: Vertical angle of the viewer's eyes above horizontal from the screen center (`observerElevationAngle`, default `20.0°`, range `0°–60°`).
4. **Observer Viewing Distance (D)**: Distance from eyes to screen center as a multiple of screen height (`viewingDistance`, default `6.0`).

### Mathematical Model:
In room coordinates (origin at screen bottom hinge, Z forward toward viewer, Y up, X right):
- Absolute screen tilt relative to ground: `theta_world = theta_hinge + beta_base`.
- Screen surface normal unit vector:
  `N = (0, sin(theta_world), cos(theta_world))`
- Observer line-of-sight unit vector from screen center:
  `V = (0, sin(alpha), cos(alpha))`
- Screen-to-Observer incidence:
  `cos(phi) = N . V = sin(theta_world)*sin(alpha) + cos(theta_world)*cos(alpha) = cos(theta_world - alpha)`
- Perceived fold onset:
  When the user sits higher (e.g. `alpha = 25°`), the screen surface turns away from their line of sight sooner during the closing arc. The perceived fold factor dynamically scales the effective `recession` and adjusts the projection vanishing point:
  `separation_effective = min(recession * travel * (1 + k_view * sin(alpha)), maxSeparationDegrees)`

### Implementation Progress:
- [x] **`Sources/MacFold/Preferences.swift`**:
  - Added `observerElevationAngle: Double` (default `20.0°`).
  - Added `baseTiltAngle: Double` (default `0.0°`).
  - Added keys, factory defaults, `defaults.register`, `defaults.double(forKey:)`, and `resetToDefaults()`.
  - Cleanly compiles with zero errors.
- [x] **`Sources/MacFold/DepthOverlay.swift`**:
  - `DepthTuning` now carries `observerElevation` and `baseTilt`.
  - `DepthGeometry.corners()` uses a fixed observer position in room coordinates, adjusted for keyboard-base tilt, and applies a bounded elevation-based perceived-separation scale.
- [x] **`Sources/MacFold/LidController.swift`**: passes both new preferences into `DepthTuning` every frame.
- [x] **`Sources/MacFold/MacBookHingeView.swift`**: draws an observer eye and sight-line cue; it also labels a non-flat base setting.
- [x] **`Sources/MacFold/SettingsView.swift`**: adds the **Observer Position** group with Eye Height (0°–60°) and Base Tilt (0°–30°).
- [x] **`Localizable.strings` (en & zh-Hans)**: contains the observer-position labels and help text.
- [x] **Build, packaging, and documentation**:
  - `./build.sh --run` completed successfully.
  - `Info.plist` is version `1.0.4`.
  - `build/release/Mac-Fold-1.0.4.dmg` was verified by `hdiutil`.
  - README documents View-Based Fold Geometry.
- [ ] **Physical behavior and release publication**:
  - The implementation was committed and pushed to `main` as `48cd5bb`.
  - User must test a real close/open through 90° with Screen Recording granted before publishing GitHub release `v1.0.4`.

---

## 4. CODEBASE FILE TREE & RESPONSIBILITIES

```text
/Users/Yatin/Documents/GitHub/Mac-Fold
├── .github/workflows/release.yml       CI: Xcode build, sign, notarize, release (macos-15)
├── Package.swift                       SwiftPM manifest (macOS 14, Swift v5 mode)
├── README.md                           Documentation, badges, installation & shortcuts
├── CODEX_HANDOFF.md                    This comprehensive handoff document
├── LICENSE                             Apache 2.0 license
├── NOTICE                              Upstream attribution (preserve)
├── assets/
│   └── menu.png                        Dark mode UI screenshot in README
├── build.sh                            Build, sign, bundle, and launch script
├── Resources/
│   ├── AppIcon.icns                    Mac Fold side-profile app icon
│   ├── AppIcon.svg                     Vector source of app icon
│   └── Info.plist                      Bundle ID local.yatin.mac-fold, LSUIElement=true
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
│       ├── MenuBarView.swift           Minimal popover: hinge view, quick toggles, observer sliders, liquid buttons
│       ├── MacBookHingeView.swift      Dynamic SwiftUI Canvas MacBook side profile
│       ├── LiquidGlass.swift           Liquid glass button styles, pill buttons, theme switcher
│       ├── SettingsView.swift          Full settings pane UI (SwiftUI)
│       ├── SettingsWindowController.swift AppKit NSWindowController for Cmd+, settings
│       ├── SettingsLanguage.swift      Localization helper
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

## 5. HARDWARE, BUILD & SENSOR GROUND TRUTH

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
  # Use a staging folder containing Mac Fold.app plus an Applications link.
  # See the build/release packaging procedure in the current agent turn.
  ```

---

## 6. CRITICAL RULES & INVARIANTS

1. **Path**: Always use `/Users/Yatin/Documents/GitHub/Mac-Fold`. Never use `/Users/Yatin/Documents/ChatGPT/mac fold app`.
2. **App Branding**: App name is **Mac Fold**. Do not revert to Mac Duo.
3. **Legal Notices**: Keep `NOTICE` and `LICENSE` files intact.
4. **Hysteresis = 0**: The trigger threshold must remain strictly 90°. Do not add positive hysteresis.
5. **Velocity Gate**: The effect must only activate on active close (<= -2 deg/s). Never activate on a stationary lid.
6. **ScreenCaptureKit Exclusion**: The capture filter MUST exclude Mac Fold's own windows (`contentFilter = SCContentFilter(...)`). Removing this creates an infinite visual feedback loop.
7. **Menu Bar Popover**: Keep `MenuBarView` minimal in the popover; do not replace it with the heavy settings view.

---

## 7. IMMEDIATE NEXT STEPS

When picking up work:
1. Ask the user to physically test the already-running 1.0.4 app: above 90° (no effect), deliberate close below 90° (effect starts), observer sliders (perspective changes), and opening to 90° (effect ends exactly there).
2. If the behavior passes, tag `v1.0.4` and publish `build/release/Mac-Fold-1.0.4.dmg` to GitHub.
3. If the behavior fails, collect the real angle and exact visible result, then adjust `DepthGeometry.corners()` rather than weakening the 90° gate or removing the velocity check.

### Camera-assisted viewpoint update (v1.0.5, current uncommitted work)

- `ViewerPositionTracker.swift` uses AVFoundation and Vision face detection only after camera permission is explicitly granted. Frames stay in memory and are never written or uploaded.
- It calibrates a relative eye-height and apparent-distance baseline, then updates `observerElevationAngle` and `viewingDistance`, which already flow into `DepthTuning` and the Metal projection.
- It cannot automatically and accurately measure base tilt relative to the ground: the built-in camera is attached to the moving lid, not the keyboard base or the room. `baseTiltAngle` remains user calibrated/manual by design.
- `NSCameraUsageDescription` is set in `Resources/Info.plist`; the full settings window has calibration/status controls and the menu bar has a compact tracking switch/status.
- `AUTO_UPDATE_CHECKLIST.md` records the required Developer ID, notarization, signed appcast, and user-consent work before a self-updater may be enabled. No fake/insecure self-update mechanism was added.

### Automatic eye tracking and update checking (v1.0.6, current uncommitted work)

- `ViewerPositionTracker` now uses Vision left/right eye landmarks every processed frame to update eye elevation automatically. It no longer requires a calibration step for elevation; calibration is only retained as an optional relative viewing-distance baseline.
- The fold’s default `recession = 1` is the comfortable-content hold: it counter-rotates the captured image while the physical lid continues to follow the hinge. Do not alter strict 90° activation/release behavior.
- `UpdateController` checks the public GitHub releases API once per day when the user enables automatic checks. The app has Settings and app-menu checks, and opens the newest release when one is found.
- It intentionally does not self-replace yet. A true installer requires the Developer ID / notarization / signed EdDSA appcast process in `AUTO_UPDATE_CHECKLIST.md`; an ad-hoc release cannot safely provide the requested in-place update button.


### Hinge-compensated camera eye tracking (v1.0.7)

- `ViewerPositionTracker` now receives live physical hinge angles and base tilt directly from `LidController`.
- The webcam physically tilts as the MacBook lid moves. The tracker calculates room-relative camera elevation: `cameraWorldElevation = hingeAngle + baseTiltAngle - 90`, and combines it with the optical eye offset `cameraOffset`. This prevents lid closure from being misread as the observer ducking or moving their head.
- Built and validated `build/release/Mac-Fold-1.0.7.dmg` with SHA-256 `96416fd47f66556a12da4d16287766138fea83452d7b7677b4bb9fcbfdad3029`.
