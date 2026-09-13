import SwiftUI

/// Minimal, elegant menu bar popover view.
/// Shows the real-time angle-accurate MacBook, quick essential controls,
/// theme switcher, liquid glass action button, and the [ Settings ] / [ Quit ] pill buttons.
struct MenuBarView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: LidController
    @AppStorage("settingsLanguage") private var language = ""

    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private var selectedLanguage: SettingsLanguage {
        SettingsLanguage(rawValue: language) ?? .preferred
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localized(key)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Mac Fold")
                        .font(.headline.weight(.bold))
                }

                Spacer()

                // Dark / Light / System Mode Switcher
                ThemeSwitchButton(preferences: preferences)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Live Angle-Accurate MacBook Visual
            MacBookHingeView(
                angle: controller.currentAngle,
                isEnabled: preferences.isEnabled,
                compact: false,
                observerElevationAngle: preferences.observerElevationAngle,
                baseTiltAngle: preferences.baseTiltAngle
            )
            .padding(.horizontal, 10)
            .padding(.top, 4)

            // Minimal Essential Controls (Liquid Glass Card)
            VStack(spacing: 8) {
                quickToggleRow(
                    title: localized("Fold Effect"),
                    subtitle: localized("Leans screen when closing < 90°"),
                    isOn: $preferences.isEnabled,
                    icon: "arrow.down.forward.and.arrow.up.backward"
                )

                quickToggleRow(
                    title: localized("Live Mirroring"),
                    subtitle: localized("Mirrors live desktop via Metal"),
                    isOn: $preferences.isLivePicture,
                    icon: "display"
                )
                .disabled(!preferences.isEnabled)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.75)
            )
            .padding(.horizontal, 14)
            .padding(.top, 6)

            // Keep the view-based controls in the quick popover as requested,
            // without bringing the full settings pane into the menu bar.
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                        .foregroundStyle(.cyan)
                    Text(localized("View-Based Perspective"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.0f° · %.0f°", preferences.observerElevationAngle, preferences.baseTiltAngle))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                compactSlider(
                    title: localized("Eye Height"),
                    value: $preferences.observerElevationAngle,
                    range: 0...60
                )
                compactSlider(
                    title: localized("Base Tilt"),
                    value: $preferences.baseTiltAngle,
                    range: 0...30
                )
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.cyan.opacity(0.16), lineWidth: 0.75)
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Liquid Glass Action Button (Preview Fold Effect)
            LiquidGlassActionButton(
                title: "Test Fold Effect",
                icon: "sparkles",
                tint: .cyan
            ) {
                controller.runPreview()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 12)

            // Bottom Pill Buttons: [ ⚙ Settings ]    [ ⏻ Quit ]
            SettingsPillBar(
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
        }
        .frame(width: 300)
        .preferredColorScheme(preferences.colorScheme)
    }

    private func quickToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func compactSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            Slider(value: value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
            Text(String(format: "%.0f°", value.wrappedValue))
                .font(.caption2.monospacedDigit())
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }
}
