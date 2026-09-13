import SwiftUI

@main
struct IPhoneDuoApp: App {
    var body: some Scene {
        WindowGroup("iPhone Duo") {
            DuoStage()
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}

private struct DuoStage: View {
    @State private var sensor = LidAngleReader()
    @State private var previewAngle: Double = 92
    @State private var isInfoVisible = true
    @State private var isDragging = false

    private let minimumAngle = 25.0
    private let maximumAngle = 145.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.035, blue: 0.075), Color(red: 0.11, green: 0.025, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TimelineView(.animation) { context in
                let pulse = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 1.35)
                Circle()
                    .fill(.cyan.opacity(0.06 + pulse * 0.03))
                    .frame(width: 760, height: 760)
                    .blur(radius: 34)
                    .offset(x: -260, y: -180)
            }

            VStack(spacing: 0) {
                header
                Spacer(minLength: 10)
                phones
                Spacer(minLength: 10)
                controls
            }
            .padding(28)
        }
        .focusable()
        .onKeyPress(.leftArrow) { changeAngle(by: -4); return .handled }
        .onKeyPress(.rightArrow) { changeAngle(by: 4); return .handled }
        .onKeyPress(.space) {
            guard !sensor.isAvailable else { return .handled }
            withAnimation(.spring) { previewAngle = 92 }
            return .handled
        }
        .gesture(DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDragging = true
                if !sensor.isAvailable { setPreviewAngle(92 - value.translation.height * 0.35) }
            }
            .onEnded { _ in isDragging = false })
        .task { sensor.start() }
        .onDisappear { sensor.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("iPhone Duo")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Interactive dual-device motion study")
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            Button(isInfoVisible ? "Hide guide" : "Show guide") {
                withAnimation(.easeInOut) { isInfoVisible.toggle() }
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
    }

    private var phones: some View {
        GeometryReader { proxy in
            let openness = (drivenAngle - minimumAngle) / (maximumAngle - minimumAngle)
            let spread = 42 + openness * min(195, proxy.size.width * 0.22)
            let rotation = 10 + openness * 26

            ZStack {
                Phone(color: .blue, title: "00:00", subtitle: "one")
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.55)
                    .offset(x: -spread, y: 12 - openness * 25)
                    .shadow(color: .blue.opacity(0.45), radius: 36, y: 20)

                Phone(color: .purple, title: "00:00", subtitle: "two")
                    .rotation3DEffect(.degrees(-rotation), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
                    .offset(x: spread, y: 12 - openness * 25)
                    .shadow(color: .purple.opacity(0.45), radius: 36, y: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.78), value: drivenAngle)
        }
        .frame(height: 420)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "angle")
                    .foregroundStyle(.cyan)
                Text("Motion input")
                    .foregroundStyle(.white.opacity(0.76))
                Slider(value: $previewAngle, in: minimumAngle...maximumAngle, step: 0.1)
                    .tint(.cyan)
                    .disabled(sensor.isAvailable)
                Text("\(Int(drivenAngle.rounded()))°")
                    .monospacedDigit()
                    .frame(width: 46, alignment: .trailing)
                    .foregroundStyle(.white)
            }

            if isInfoVisible {
                Text(sensor.isAvailable ? "Reading your MacBook’s internal lid-angle sensor. Preview controls are disabled while live input is active." : "\(sensor.status) Use the slider or ← / → preview controls.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func changeAngle(by amount: Double) {
        guard !sensor.isAvailable else { return }
        withAnimation(.interactiveSpring) { setPreviewAngle(previewAngle + amount) }
    }

    private var drivenAngle: Double {
        sensor.isAvailable ? sensor.angle : previewAngle
    }

    private func setPreviewAngle(_ newValue: Double) {
        previewAngle = min(maximumAngle, max(minimumAngle, newValue))
    }
}

private struct Phone: View {
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 43, style: .continuous)
                .fill(.black)
                .overlay(RoundedRectangle(cornerRadius: 43, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 2))

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.95), .black.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(8)

            VStack(spacing: 8) {
                Capsule().fill(.black.opacity(0.8)).frame(width: 92, height: 25)
                Spacer()
                Text(title).font(.system(size: 42, weight: .thin, design: .rounded))
                Text(subtitle.uppercased()).font(.caption.weight(.semibold)).tracking(3)
                Spacer()
                Circle().stroke(.white.opacity(0.7), lineWidth: 2).frame(width: 13, height: 13)
            }
            .padding(.vertical, 17)
            .foregroundStyle(.white)
        }
        .frame(width: 205, height: 395)
    }
}
