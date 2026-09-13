import SwiftUI

/// An interactive, angle-accurate vector illustration of a MacBook.
/// The display lid pivots dynamically around the rear hinge to match
/// the exact physical angle reported by the hardware hinge sensor.
struct MacBookHingeView: View {
    let angle: Double
    var isEnabled: Bool = true
    var compact: Bool = false

    private var clampedAngle: Double {
        max(0, min(angle, 150))
    }

    private var isFoldActive: Bool {
        clampedAngle < 90.0 && isEnabled
    }

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            ZStack {
                // Background ambient glow when fold is active
                if isFoldActive {
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: compact ? 70 : 100
                    )
                    .blur(radius: 12)
                }

                Canvas { context, size in
                    drawMacBook(context: context, size: size)
                }
                .frame(
                    width: compact ? 220 : 270,
                    height: compact ? 120 : 145
                )
            }

            // Live status & angle badge
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isFoldActive ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text(isFoldActive ? "Fold Active (< 90°)" : "Normal (≥ 90°)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isFoldActive ? Color.orange : Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            (isFoldActive ? Color.orange : Color.secondary).opacity(0.25),
                            lineWidth: 0.5
                        )
                )

                Spacer()

                Text(String(format: "%.1f°", clampedAngle))
                    .font(.system(compact ? .caption : .subheadline, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(isFoldActive ? Color.orange : Color.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, compact ? 10 : 16)
        }
        .padding(.vertical, compact ? 6 : 10)
    }

    private func drawMacBook(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height

        // Coordinate space:
        // Hinge pivot at rear left
        let pivotX = width * 0.32
        let pivotY = height * 0.78

        let baseLength = width * 0.56
        let baseThickness: CGFloat = 8
        let lidLength = width * 0.52
        let lidThickness: CGFloat = 4.5

        let rad = clampedAngle * .pi / 180.0

        // 1. Draw angle arc
        let arcRadius: CGFloat = 32
        var arcPath = Path()
        arcPath.addArc(
            center: CGPoint(x: pivotX, y: pivotY),
            radius: arcRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(-clampedAngle),
            clockwise: true
        )
        context.stroke(
            arcPath,
            with: .color(isFoldActive ? Color.orange.opacity(0.7) : Color.accentColor.opacity(0.4)),
            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
        )

        // 2. Draw base shadow
        let shadowRect = CGRect(x: pivotX - 8, y: pivotY + baseThickness + 1, width: baseLength + 14, height: 6)
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(Color.black.opacity(0.25))
        )

        // 3. Draw Base (Keyboard deck)
        var basePath = Path()
        let baseRect = CGRect(x: pivotX - 4, y: pivotY, width: baseLength, height: baseThickness)
        basePath.addRoundedRect(in: baseRect, cornerSize: CGSize(width: 3, height: 3))

        let baseGradient = Gradient(colors: [
            Color(white: 0.75),
            Color(white: 0.55),
            Color(white: 0.40)
        ])
        context.fill(
            basePath,
            with: .linearGradient(
                baseGradient,
                startPoint: CGPoint(x: pivotX, y: pivotY),
                endPoint: CGPoint(x: pivotX, y: pivotY + baseThickness)
            )
        )
        context.stroke(basePath, with: .color(Color.black.opacity(0.4)), lineWidth: 0.75)

        // Subtle rubber feet
        let foot1 = CGRect(x: pivotX + 16, y: pivotY + baseThickness, width: 10, height: 2)
        let foot2 = CGRect(x: pivotX + baseLength - 26, y: pivotY + baseThickness, width: 10, height: 2)
        context.fill(Path(roundedRect: foot1, cornerRadius: 1), with: .color(Color(white: 0.25)))
        context.fill(Path(roundedRect: foot2, cornerRadius: 1), with: .color(Color(white: 0.25)))

        // Subtle side port (USB-C)
        let portRect = CGRect(x: pivotX + 18, y: pivotY + 2.5, width: 7, height: 2.5)
        context.fill(Path(roundedRect: portRect, cornerRadius: 1), with: .color(Color(white: 0.2)))

        // 4. Draw Display Lid
        // Direction vector:
        // Angle 0: pointing along +X (dx = 1, dy = 0)
        // Angle 90: pointing along -Y (dx = 0, dy = -1)
        // Angle 135: leaning back (dx = cos(135), dy = -sin(135))
        let cosA = CGFloat(cos(rad))
        let sinA = CGFloat(sin(rad))

        // Normal perpendicular vector pointing "upward/inward" from lid
        let normX = -sinA * lidThickness
        let normY = -cosA * lidThickness

        let tipX = pivotX + cosA * lidLength
        let tipY = pivotY - sinA * lidLength

        // Outer lid aluminum shell
        var lidPath = Path()
        lidPath.move(to: CGPoint(x: pivotX, y: pivotY))
        lidPath.addLine(to: CGPoint(x: tipX, y: tipY))
        lidPath.addLine(to: CGPoint(x: tipX + normX, y: tipY + normY))
        lidPath.addLine(to: CGPoint(x: pivotX + normX, y: pivotY + normY))
        lidPath.closeSubpath()

        let lidGradient = Gradient(colors: [
            Color(white: 0.82),
            Color(white: 0.65),
            Color(white: 0.48)
        ])
        context.fill(
            lidPath,
            with: .linearGradient(
                lidGradient,
                startPoint: CGPoint(x: pivotX, y: pivotY),
                endPoint: CGPoint(x: tipX, y: tipY)
            )
        )
        context.stroke(lidPath, with: .color(Color.black.opacity(0.35)), lineWidth: 0.75)

        // Screen face (active display surface)
        var screenFacePath = Path()
        let screenOffset: CGFloat = 0.5
        let sP0 = CGPoint(x: pivotX + normX * screenOffset, y: pivotY + normY * screenOffset)
        let sP1 = CGPoint(x: tipX + normX * screenOffset, y: tipY + normY * screenOffset)
        screenFacePath.move(to: sP0)
        screenFacePath.addLine(to: sP1)

        let screenColor = isFoldActive ? Color.orange : Color.cyan
        context.stroke(
            screenFacePath,
            with: .color(screenColor.opacity(0.85)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        // 5. Rear hinge barrel
        let hingeRadius: CGFloat = 5
        let hingeRect = CGRect(x: pivotX - hingeRadius, y: pivotY - hingeRadius + 1, width: hingeRadius * 2, height: hingeRadius * 2)
        var hingePath = Path()
        hingePath.addEllipse(in: hingeRect)
        context.fill(
            hingePath,
            with: .radialGradient(
                Gradient(colors: [Color(white: 0.9), Color(white: 0.4)]),
                center: CGPoint(x: pivotX - 1, y: pivotY),
                startRadius: 1,
                endRadius: hingeRadius
            )
        )
        context.stroke(hingePath, with: .color(Color.black.opacity(0.45)), lineWidth: 0.75)
    }
}
