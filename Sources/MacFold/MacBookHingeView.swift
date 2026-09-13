import SwiftUI

/// An interactive, angle-accurate vector illustration of a MacBook.
/// The display lid pivots dynamically around the rear hinge to match
/// the exact physical angle reported by the hardware hinge sensor.
struct MacBookHingeView: View {
    let angle: Double
    var isEnabled: Bool = true
    var compact: Bool = false
    var observerElevationAngle: Double = 20
    var baseTiltAngle: Double = 0

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

                if baseTiltAngle > 0.5 {
                    HStack(spacing: 3) {
                        Image(systemName: "angle")
                            .font(.system(size: 8))
                            .foregroundStyle(.cyan)
                        Text(String(format: "Base %.0f°", baseTiltAngle))
                            .font(.system(size: 10, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
                }

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

        // Ground plane height
        let groundY = height * 0.82
        let pivotX = width * 0.28
        let pivotY = groundY - 6.0

        let baseLength = width * 0.58
        let baseThickness: CGFloat = compact ? 7.0 : 8.5
        let lidLength = width * 0.54
        let lidThickness: CGFloat = compact ? 4.0 : 4.8

        let baseTilt = max(0, min(baseTiltAngle, 35))
        let baseRad = baseTilt * .pi / 180.0

        // 1. Soft ground contact shadow
        let shadowWidth = baseLength * 1.08
        let shadowRect = CGRect(
            x: pivotX - 10,
            y: groundY + (baseTilt > 0 ? 1 : 2),
            width: shadowWidth,
            height: compact ? 6 : 8
        )
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(Color.black.opacity(0.38))
        )

        // 2. Base vectors & geometry
        // When base tilts, it slopes upward relative to the ground
        let cosB = CGFloat(cos(baseRad))
        let sinB = CGFloat(sin(baseRad))
        let vBaseX = cosB
        let vBaseY = -sinB

        // Perpendicular vector for base thickness (downward/outward)
        let nBaseX = sinB * baseThickness
        let nBaseY = cosB * baseThickness

        let baseTipX = pivotX + vBaseX * baseLength
        let baseTipY = pivotY + vBaseY * baseLength

        // If base is tilted to the ground, draw a subtle horizontal ground guide
        if baseTilt > 1.0 {
            var groundGuide = Path()
            groundGuide.move(to: CGPoint(x: pivotX - 4, y: pivotY + nBaseY))
            groundGuide.addLine(to: CGPoint(x: pivotX + baseLength, y: pivotY + nBaseY))
            context.stroke(
                groundGuide,
                with: .color(Color.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )

            // Small base tilt angle arc
            var baseArc = Path()
            baseArc.addArc(
                center: CGPoint(x: pivotX, y: pivotY + nBaseY),
                radius: 20,
                startAngle: .degrees(0),
                endAngle: .degrees(-baseTilt),
                clockwise: true
            )
            context.stroke(
                baseArc,
                with: .color(Color.cyan.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
        }

        // 3. Draw Base (Keyboard deck)
        // Draw smoothly rounded trapezoid / pill body
        var basePath = Path()
        basePath.move(to: CGPoint(x: pivotX, y: pivotY))
        basePath.addLine(to: CGPoint(x: baseTipX, y: baseTipY))
        basePath.addLine(to: CGPoint(x: baseTipX + nBaseX, y: baseTipY + nBaseY))
        basePath.addLine(to: CGPoint(x: pivotX + nBaseX, y: pivotY + nBaseY))
        basePath.closeSubpath()

        let baseGradient = Gradient(colors: [
            Color(white: 0.80),
            Color(white: 0.58),
            Color(white: 0.38)
        ])
        context.fill(
            basePath,
            with: .linearGradient(
                baseGradient,
                startPoint: CGPoint(x: pivotX, y: pivotY),
                endPoint: CGPoint(x: pivotX + nBaseX, y: pivotY + nBaseY)
            )
        )
        context.stroke(basePath, with: .color(Color.black.opacity(0.40)), lineWidth: 0.8)

        // Front rounded bumper
        let frontRadius = baseThickness * 0.45
        var frontCap = Path()
        frontCap.addEllipse(in: CGRect(
            x: baseTipX - frontRadius,
            y: baseTipY + (nBaseY - frontRadius * 2) * 0.5,
            width: frontRadius * 2,
            height: frontRadius * 2
        ))
        context.fill(frontCap, with: .color(Color(white: 0.65)))

        // Subtle side port (USB-C cutout)
        let portOffset = baseLength * 0.16
        let portX = pivotX + vBaseX * portOffset
        let portY = pivotY + vBaseY * portOffset + nBaseY * 0.35
        var portPath = Path()
        portPath.addRoundedRect(
            in: CGRect(x: portX, y: portY, width: 8, height: 3),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        context.fill(portPath, with: .color(Color(white: 0.18)))

        // Bottom rubber feet
        let foot1X = pivotX + vBaseX * (baseLength * 0.14) + nBaseX
        let foot1Y = pivotY + vBaseY * (baseLength * 0.14) + nBaseY
        let foot2X = pivotX + vBaseX * (baseLength * 0.85) + nBaseX
        let foot2Y = pivotY + vBaseY * (baseLength * 0.85) + nBaseY
        var footPath = Path()
        footPath.addRoundedRect(in: CGRect(x: foot1X, y: foot1Y, width: 9, height: 2), cornerSize: CGSize(width: 1, height: 1))
        footPath.addRoundedRect(in: CGRect(x: foot2X, y: foot2Y, width: 9, height: 2), cornerSize: CGSize(width: 1, height: 1))
        context.fill(footPath, with: .color(Color(white: 0.22)))

        // 4. Draw Display Lid
        // Total angle in standard Cartesian (counter-clockwise from +X):
        // Lid extends from hinge at angle (clampedAngle - baseTilt)
        let totalLidAngle = clampedAngle - baseTilt
        let totalLidRad = totalLidAngle * .pi / 180.0

        let cosL = CGFloat(cos(totalLidRad))
        let sinL = CGFloat(sin(totalLidRad))
        let vLidX = cosL
        let vLidY = -sinL

        // Perpendicular vector for lid thickness (pointing upward/inward into hinge)
        let nLidX = -sinL * lidThickness
        let nLidY = -cosL * lidThickness

        let tipX = pivotX + vLidX * lidLength
        let tipY = pivotY + vLidY * lidLength

        // Outer aluminum lid shell
        var lidPath = Path()
        lidPath.move(to: CGPoint(x: pivotX, y: pivotY))
        lidPath.addLine(to: CGPoint(x: tipX, y: tipY))
        lidPath.addLine(to: CGPoint(x: tipX + nLidX, y: tipY + nLidY))
        lidPath.addLine(to: CGPoint(x: pivotX + nLidX, y: pivotY + nLidY))
        lidPath.closeSubpath()

        let lidGradient = Gradient(colors: [
            Color(white: 0.85),
            Color(white: 0.68),
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
        context.stroke(lidPath, with: .color(Color.black.opacity(0.38)), lineWidth: 0.8)

        // Screen face (Active display surface with vibrant neon cyan glow, exactly like reference)
        var screenFacePath = Path()
        let screenOffset: CGFloat = 0.5
        let sP0 = CGPoint(x: pivotX + nLidX * screenOffset, y: pivotY + nLidY * screenOffset)
        let sP1 = CGPoint(x: tipX + nLidX * screenOffset, y: tipY + nLidY * screenOffset)
        screenFacePath.move(to: sP0)
        screenFacePath.addLine(to: sP1)

        let screenColor = isFoldActive
            ? Color.orange
            : Color(red: 0.05, green: 0.78, blue: 0.98) // Vibrant electric cyan from reference

        // Outer glow
        context.stroke(
            screenFacePath,
            with: .color(screenColor.opacity(0.35)),
            style: StrokeStyle(lineWidth: compact ? 3.5 : 4.5, lineCap: .round)
        )
        // Core bright line
        context.stroke(
            screenFacePath,
            with: .color(screenColor),
            style: StrokeStyle(lineWidth: compact ? 1.8 : 2.4, lineCap: .round)
        )

        // 5. Dashed Hinge Angle Arc
        // Measures opening angle between base and display lid
        let arcRadius: CGFloat = compact ? 28 : 36
        var arcPath = Path()
        arcPath.addArc(
            center: CGPoint(x: pivotX, y: pivotY),
            radius: arcRadius,
            startAngle: .degrees(-baseTilt),
            endAngle: .degrees(-(baseTilt + clampedAngle)),
            clockwise: true
        )
        context.stroke(
            arcPath,
            with: .color(isFoldActive ? Color.orange.opacity(0.75) : Color.white.opacity(0.38)),
            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
        )

        // 6. 3D Spherical Hinge Joint (Realistic metal sphere from reference image)
        let hingeRadius: CGFloat = compact ? 6.5 : 8.5
        let hingeCenter = CGPoint(x: pivotX, y: pivotY)
        let hingeRect = CGRect(
            x: hingeCenter.x - hingeRadius,
            y: hingeCenter.y - hingeRadius,
            width: hingeRadius * 2,
            height: hingeRadius * 2
        )
        var hingePath = Path()
        hingePath.addEllipse(in: hingeRect)

        // Spherical 3D lighting: specular point at top-left
        let specularCenter = CGPoint(
            x: hingeCenter.x - hingeRadius * 0.32,
            y: hingeCenter.y - hingeRadius * 0.32
        )
        context.fill(
            hingePath,
            with: .radialGradient(
                Gradient(colors: [
                    Color(white: 0.98),
                    Color(white: 0.78),
                    Color(white: 0.52),
                    Color(white: 0.28)
                ]),
                center: specularCenter,
                startRadius: 0.5,
                endRadius: hingeRadius
            )
        )
        context.stroke(hingePath, with: .color(Color.black.opacity(0.50)), lineWidth: 0.8)

        // 7. Observer Viewpoint & Sightline (Cyan dot & dashed sight line straight to screen center)
        let screenCenter = CGPoint(
            x: pivotX + vLidX * (lidLength * 0.5) + nLidX * 0.5,
            y: pivotY + vLidY * (lidLength * 0.5) + nLidY * 0.5
        )

        let eyeElevation = max(0, min(observerElevationAngle, 60)) * .pi / 180
        let eyeDistance: CGFloat = compact ? 42 : 55
        let eyeOrigin = CGPoint(
            x: pivotX + baseLength * 0.65,
            y: pivotY - 12 - (baseTilt > 0 ? sinB * 8 : 0)
        )
        let eye = CGPoint(
            x: eyeOrigin.x + cos(eyeElevation) * eyeDistance,
            y: eyeOrigin.y - sin(eyeElevation) * eyeDistance
        )

        var sightLine = Path()
        sightLine.move(to: eye)
        sightLine.addLine(to: screenCenter)
        context.stroke(
            sightLine,
            with: .color(Color(red: 0.05, green: 0.78, blue: 0.98).opacity(0.48)),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
        )

        // Observer eye marker dot
        let eyeDotRadius: CGFloat = compact ? 3.0 : 4.0
        let eyeRect = CGRect(
            x: eye.x - eyeDotRadius,
            y: eye.y - eyeDotRadius,
            width: eyeDotRadius * 2,
            height: eyeDotRadius * 2
        )
        // Outer glow halo
        context.fill(
            Path(ellipseIn: eyeRect.insetBy(dx: -1.5, dy: -1.5)),
            with: .color(Color(red: 0.05, green: 0.78, blue: 0.98).opacity(0.25))
        )
        // Bright cyan core
        context.fill(
            Path(ellipseIn: eyeRect),
            with: .color(Color(red: 0.05, green: 0.78, blue: 0.98))
        )
    }
}
