import SwiftUI

/// Modern macOS / visionOS style Liquid Glass button style and components.
struct LiquidGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    var isProminent: Bool = false
    var accentTint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Frosted glass background
                    if isProminent {
                        (accentTint ?? Color.accentColor).opacity(configuration.isPressed ? 0.35 : 0.22)
                    } else {
                        Color.white.opacity(configuration.isPressed ? 0.14 : 0.07)
                    }

                    // Translucent blur material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Specular light sheen across the top edge
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isProminent ? 0.35 : 0.22),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isProminent ? 0.45 : 0.28),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: (accentTint ?? Color.black).opacity(isProminent ? 0.25 : 0.15),
                radius: configuration.isPressed ? 2 : 4,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Bottom pill buttons matching the user's reference image:
/// [ ⚙ Settings ]    [ ⏻ Quit ]
struct SettingsPillBar: View {
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Settings Button
            Button(action: onOpenSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())

            // Quit Button
            Button(action: onQuit) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Quit")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Exact pill button style matching the user's reference image:
/// Translucent dark rounded pill with subtle 1px border.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.06))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Standalone prominent Liquid Glass action button.
struct LiquidGlassActionButton: View {
    let title: String
    let icon: String
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 10, isProminent: true, accentTint: tint))
        .onHover { isHovering = $0 }
    }
}

/// Liquid glass Dark / Light / System appearance switcher button.
struct ThemeSwitchButton: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Button(action: cycleTheme) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .help("Switch Appearance (\(preferences.appTheme.capitalized))")
    }

    private var iconName: String {
        switch preferences.appTheme {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.righthalf.filled"
        }
    }

    private var iconColor: Color {
        switch preferences.appTheme {
        case "light": return .orange
        case "dark": return .indigo
        default: return .primary
        }
    }

    private func cycleTheme() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            switch preferences.appTheme {
            case "system": preferences.appTheme = "dark"
            case "dark": preferences.appTheme = "light"
            case "light": preferences.appTheme = "system"
            default: preferences.appTheme = "system"
            }
        }
    }
}
