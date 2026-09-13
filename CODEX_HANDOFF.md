# Mac Fold — Codex Handoff

**Repository root:** `/Users/Yatin/Documents/GitHub/Mac-Fold`  
**Canonical GitHub repository:** `https://github.com/satyalayatinasish-arch/Mac-Fold`  
**Current branch:** `main`  
**Latest pushed commit on origin/main:** `bac0a5c` (`Add minimal menu bar UI, MacBook angle viz, liquid glass controls, and theme switcher`)  
**Current app version:** `1.0.3` (targeted for `1.0.4` release with View-Based Fold Effect)  
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
   - Quick toggles for Depth Effect and Live Mirroring.
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
   - Updated `assets/menu.png` with new dark mode screenshot (commit `ca79c8f`).
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

### In-Flight Progress:
- [x] **`Sources/MacFold/Preferences.swift`**:
  - Added `observerElevationAngle: Double` (default `20.0°`).
  - Added `baseTiltAngle: Double` (default `0.0°`).
  - Added keys, factory defaults, `defaults.register`, `defaults.double(forKey:)`, and `resetToDefaults()`.
  - Cleanly compiles with zero errors.
- [ ] **`Sources/MacFold/DepthOverlay.swift`**:
  - Extend `DepthTuning` struct: add `observerElevation: Double` and `baseTilt: Double`.
  - Update `DepthGeometry.corners()` to incorporate `observerElevation` and `baseTilt`.
- [ ] **`Sources/MacFold/LidController.swift`**:
  - Pass `preferences.observerElevationAngle` and `preferences.baseTiltAngle` into `tuning` computed property.
- [ ] **`Sources/MacFold/MacBookHingeView.swift`**:
  - Add optional visual observer eye dot/arc at the elevation angle above the MacBook silhouette.
- [ ] **`Sources/MacFold/SettingsView.swift`**:
  - Add **Observer Position** settings group with two clean sliders:
    - Eye Height (`observerElevationAngle`: 0°–60°)
    - Base Tilt (`baseTiltAngle`: 0°–30°)
- [ ] **`Localizable.strings` (en & zh-Hans)**:
  - Add keys: `Observer Position`, `Eye Height`, `Base Tilt`, `Floor Level`, `Elevated`, `Flat`, `Tilted`.
- [ ] **Build, Packaging, Documentation & Release**:
  - Test `./build.sh` clean compile.
  - Bump `Info.plist` version to `1.0.4`.
  - Build DMG: `build/release/Mac-Fold-1.0.4.dmg`.
  - Update `README.md` and screenshot.
  - Commit all changes, push to `main`, and create GitHub release `v1.0.4`.

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
│       ├── MenuBarView.swift           Minimal popover: hinge view, quick toggles, liquid buttons
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
  hdiutil create -volname 'Mac Fold' -srcfolder 'build/Mac Fold.app' -fs HFS+ -format UDZO build/release/Mac-Fold-1.0.4.dmg
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

## 7. IMMEDIATE NEXT STEPS TO COMPLETE THE IN-FLIGHT FEATURE

When picking up work:
1. Check `git status` (only `Sources/MacFold/Preferences.swift` is currently modified with the new properties).
2. Edit `Sources/MacFold/DepthOverlay.swift`:
   - Add `observerElevation` and `baseTilt` to `DepthTuning`.
   - Update `DepthGeometry.corners()` to adjust separation/recession according to observer elevation and base tilt.
3. Edit `Sources/MacFold/LidController.swift`:
   - Update `tuning` property to pass `preferences.observerElevationAngle` and `preferences.baseTiltAngle`.
4. Edit `Sources/MacFold/MacBookHingeView.swift`:
   - Draw an observer indicator on the canvas at the eye angle.
5. Edit `Sources/MacFold/SettingsView.swift`:
   - Add the "Observer Position" section with sliders for Eye Height and Base Tilt.
6. Edit `Localizable.strings` (en and zh-Hans) for the new labels.
7. Compile and run: `./build.sh --run`.
8. Bump version in `Resources/Info.plist` to `1.0.4`.
9. Package DMG: `build/release/Mac-Fold-1.0.4.dmg`.
10. Commit changes: `git commit -am "Implement observer-perspective view-based fold effect"` and push to `origin/main`.
11. Create GitHub release `v1.0.4` with the DMG.
