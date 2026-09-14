import Combine
import Foundation
import SwiftUI

/// User settings, backed by `UserDefaults`.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let isEnabled = "isEnabled"
        static let isTimeoutEnabled = "isTimeoutEnabled"
        static let thresholdAngle = "thresholdAngle"
        static let blurSpan = "blurSpan"
        static let maxBlurRadius = "maxBlurRadius"
        static let maxDim = "maxDim"
        static let viewingDistance = "viewingDistance"
        static let recession = "recession"
        static let blurEvenness = "blurEvenness"
        static let dimReach = "dimReach"
        static let showsAngleInMenuBar = "showsAngleInMenuBar"
        static let isLivePicture = "isLivePicture"
        static let appTheme = "appTheme"
        static let observerElevationAngle = "observerElevationAngle"
        static let baseTiltAngle = "baseTiltAngle"
        static let isCameraViewTracking = "isCameraViewTracking"
        static let isAutomaticUpdateChecks = "isAutomaticUpdateChecks"
        static let isMenuBarIconHidden = "isMenuBarIconHidden"

        static let all = [
            isEnabled, isTimeoutEnabled, thresholdAngle, blurSpan, maxBlurRadius,
            maxDim, viewingDistance, recession, blurEvenness, dimReach,
            showsAngleInMenuBar, isLivePicture, appTheme,
            observerElevationAngle, baseTiltAngle, isCameraViewTracking, isAutomaticUpdateChecks,
            isMenuBarIconHidden,
        ]
    }

    private static let factory: [String: Any] = [
        Key.isEnabled: true,
        Key.isTimeoutEnabled: false,
        Key.thresholdAngle: 90.0,
        Key.blurSpan: 60.0,
        Key.maxBlurRadius: 135.0,
        Key.maxDim: 1.0,
        Key.viewingDistance: 6.0,
        Key.recession: 1.0,
        Key.blurEvenness: 0.0,
        Key.dimReach: 0.5,
        Key.showsAngleInMenuBar: false,
        Key.isLivePicture: true,
        Key.appTheme: "system",
        Key.observerElevationAngle: 20.0,
        Key.baseTiltAngle: 0.0,
        Key.isCameraViewTracking: false,
        Key.isAutomaticUpdateChecks: false,
        Key.isMenuBarIconHidden: false,
    ]

    /// Master switch for the depth effect.
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    /// Ends the effect early if the angle holds still while below the
    /// threshold, instead of waiting for the lid to open back past it.
    @Published var isTimeoutEnabled: Bool {
        didSet { defaults.set(isTimeoutEnabled, forKey: Key.isTimeoutEnabled) }
    }

    /// Closing past this angle starts the depth effect. Degrees.
    @Published var thresholdAngle: Double {
        didSet { defaults.set(thresholdAngle, forKey: Key.thresholdAngle) }
    }

    /// How many degrees below the threshold the blur takes to reach maximum.
    @Published var blurSpan: Double {
        didSet { defaults.set(blurSpan, forKey: Key.blurSpan) }
    }

    /// Gaussian blur radius at full effect, in points.
    @Published var maxBlurRadius: Double {
        didSet { defaults.set(maxBlurRadius, forKey: Key.maxBlurRadius) }
    }

    /// Black overlay opacity where the blur is at full strength, 0...1.
    @Published var maxDim: Double {
        didSet { defaults.set(maxDim, forKey: Key.maxDim) }
    }

    /// Distance from the eye to the middle of the screen, as a multiple of
    /// the screen height.
    @Published var viewingDistance: Double {
        didSet { defaults.set(viewingDistance, forKey: Key.viewingDistance) }
    }

    /// Degrees the picture turns away from the glass for each degree the lid
    /// closes. One holds the picture still in the room.
    @Published var recession: Double {
        didSet { defaults.set(recession, forKey: Key.recession) }
    }

    /// Blur at the hinge edge as a fraction of the blur at the far edge. One
    /// blurs the whole picture by the same amount.
    @Published var blurEvenness: Double {
        didSet { defaults.set(blurEvenness, forKey: Key.blurEvenness) }
    }

    /// Height at which the dimming reaches full strength, as a fraction of
    /// the screen height.
    @Published var dimReach: Double {
        didSet { defaults.set(dimReach, forKey: Key.dimReach) }
    }

    /// Draw the live angle next to the menu bar icon.
    @Published var showsAngleInMenuBar: Bool {
        didSet { defaults.set(showsAngleInMenuBar, forKey: Key.showsAngleInMenuBar) }
    }

    /// Keep the picture under the effect updating, instead of holding the one
    /// frame that was on screen at the trigger angle.
    @Published var isLivePicture: Bool {
        didSet { defaults.set(isLivePicture, forKey: Key.isLivePicture) }
    }

    /// User interface appearance: "system", "dark", or "light".
    @Published var appTheme: String {
        didSet { defaults.set(appTheme, forKey: Key.appTheme) }
    }

    /// SwiftUI ColorScheme corresponding to the current appTheme.
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Vertical angle (degrees) from the screen centre to the observer's eyes
    /// above the horizontal. 0° = eyes level with screen; 20° = typical seated.
    /// Range 0–60°. Higher values shift when the fold effect is felt to start.
    @Published var observerElevationAngle: Double {
        didSet { defaults.set(observerElevationAngle, forKey: Key.observerElevationAngle) }
    }

    /// Tilt of the MacBook base plane away from horizontal (degrees).
    /// 0° = flat on desk (most common). Range 0–30°. Accounts for laptop stands
    /// or angled surfaces and adjusts the screen-normal direction accordingly.
    @Published var baseTiltAngle: Double {
        didSet { defaults.set(baseTiltAngle, forKey: Key.baseTiltAngle) }
    }

    /// Uses the camera only for calibrated, in-memory viewer-position estimates.
    @Published var isCameraViewTracking: Bool {
        didSet { defaults.set(isCameraViewTracking, forKey: Key.isCameraViewTracking) }
    }

    @Published var isAutomaticUpdateChecks: Bool {
        didSet { defaults.set(isAutomaticUpdateChecks, forKey: Key.isAutomaticUpdateChecks) }
    }

    /// Hides the menu bar status item. The app remains running in the background.
    @Published var isMenuBarIconHidden: Bool {
        didSet { defaults.set(isMenuBarIconHidden, forKey: Key.isMenuBarIconHidden) }
    }

    /// Eye distance in screen heights, at the two ends of the perspective
    /// slider. The panel offers the strength, which runs the other way.
    static let farthestEye: Double = 6
    static let nearestEye: Double = 1
    static let eyeRange: Double = farthestEye - nearestEye

    /// Highest angle above the threshold at which the pre-warm may run.
    let prewarmCeiling: Double = 70

    /// Closing speed in degrees per second that starts the pre-warm.
    let closingSpeed: Double = 8

    /// How long the pre-warm runs after the lid stops moving.
    let prewarmLinger: TimeInterval = 2

    /// Seconds between pre-warm screenshots.
    let prewarmInterval: TimeInterval = 0.25

    /// Release exactly at the configured threshold. This makes the effect
    /// start below 90° while closing and end at 90° while opening.
    let hysteresis: Double = 0

    /// Settings from earlier versions, removed at launch.
    private static let retired = [
        "blurFrontWidth", "maxTilt", "tiltDegrees", "tiltRatio", "dimEvenness",
    ]

    private let defaults = UserDefaults.standard

    // No inline values on purpose. Swift skips property observers for the
    // assignment that initialises a property.
    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: Self.factory)
        for key in Self.retired { defaults.removeObject(forKey: key) }
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        isTimeoutEnabled = defaults.bool(forKey: Key.isTimeoutEnabled)
        thresholdAngle = defaults.double(forKey: Key.thresholdAngle)
        blurSpan = defaults.double(forKey: Key.blurSpan)
        maxBlurRadius = defaults.double(forKey: Key.maxBlurRadius)
        maxDim = defaults.double(forKey: Key.maxDim)
        viewingDistance = defaults.double(forKey: Key.viewingDistance)
        recession = defaults.double(forKey: Key.recession)
        blurEvenness = defaults.double(forKey: Key.blurEvenness)
        dimReach = defaults.double(forKey: Key.dimReach)
        showsAngleInMenuBar = defaults.bool(forKey: Key.showsAngleInMenuBar)
        isLivePicture = defaults.bool(forKey: Key.isLivePicture)
        appTheme = defaults.string(forKey: Key.appTheme) ?? "system"
        observerElevationAngle = defaults.double(forKey: Key.observerElevationAngle)
        baseTiltAngle = defaults.double(forKey: Key.baseTiltAngle)
        isCameraViewTracking = defaults.bool(forKey: Key.isCameraViewTracking)
        isAutomaticUpdateChecks = defaults.bool(forKey: Key.isAutomaticUpdateChecks)
        isMenuBarIconHidden = defaults.bool(forKey: Key.isMenuBarIconHidden)
    }

    func resetToDefaults() {
        for key in Key.all {
            defaults.removeObject(forKey: key)
        }
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        isTimeoutEnabled = defaults.bool(forKey: Key.isTimeoutEnabled)
        thresholdAngle = defaults.double(forKey: Key.thresholdAngle)
        blurSpan = defaults.double(forKey: Key.blurSpan)
        maxBlurRadius = defaults.double(forKey: Key.maxBlurRadius)
        maxDim = defaults.double(forKey: Key.maxDim)
        viewingDistance = defaults.double(forKey: Key.viewingDistance)
        recession = defaults.double(forKey: Key.recession)
        blurEvenness = defaults.double(forKey: Key.blurEvenness)
        dimReach = defaults.double(forKey: Key.dimReach)
        showsAngleInMenuBar = defaults.bool(forKey: Key.showsAngleInMenuBar)
        isLivePicture = defaults.bool(forKey: Key.isLivePicture)
        appTheme = "system"
        observerElevationAngle = defaults.double(forKey: Key.observerElevationAngle)
        baseTiltAngle = defaults.double(forKey: Key.baseTiltAngle)
        isCameraViewTracking = defaults.bool(forKey: Key.isCameraViewTracking)
        isAutomaticUpdateChecks = defaults.bool(forKey: Key.isAutomaticUpdateChecks)
        isMenuBarIconHidden = defaults.bool(forKey: Key.isMenuBarIconHidden)
    }
}
