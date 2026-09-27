import SwiftUI

/// Pip is drawn in SwiftUI, so it stays crisp at every size and needs no asset downloads.
struct PipMascot: View {
    var working = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: !working || reduceMotion || scenePhase != .active)) { timeline in
            // A bounded drawing transform cannot animate the surrounding layout or navigation.
            let wave = working && !reduceMotion && scenePhase == .active
                ? sin(timeline.date.timeIntervalSinceReferenceDate * .pi * 2 / 1.8) : 0
            GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Ellipse().fill(.teal.opacity(0.14))
                    .frame(width: side * 0.62, height: side * 0.1).offset(y: side * 0.39)
                ZStack {
                    // Soft pebble body, tiny arms, and a sprout: Clearspace's own companion.
                    Capsule().fill(.teal).frame(width: side * 0.17, height: side * 0.32)
                        .rotationEffect(.degrees(-32)).offset(x: -side * 0.34, y: side * 0.06)
                    Capsule().fill(.teal).frame(width: side * 0.17, height: side * 0.32)
                        .rotationEffect(.degrees(working ? -35 : 32)).offset(x: side * 0.34, y: -side * 0.02)
                    RoundedRectangle(cornerRadius: side * 0.29)
                        .fill(LinearGradient(colors: [Color(red: 0.60, green: 0.94, blue: 0.83), .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: side * 0.72, height: side * 0.7)
                        .overlay(alignment: .topLeading) {
                            Ellipse().fill(.white.opacity(0.35)).frame(width: side * 0.27, height: side * 0.10)
                                .rotationEffect(.degrees(-30)).padding(side * 0.1)
                        }
                    HStack(spacing: side * 0.15) {
                        Capsule().frame(width: side * 0.045, height: side * 0.085)
                        Capsule().frame(width: side * 0.045, height: side * 0.085)
                    }.foregroundStyle(Color(red: 0.06, green: 0.24, blue: 0.23)).offset(y: -side * 0.01)
                    HStack(spacing: side * 0.26) {
                        Ellipse().frame(width: side * 0.09, height: side * 0.04)
                        Ellipse().frame(width: side * 0.09, height: side * 0.04)
                    }.foregroundStyle(.pink.opacity(0.40)).offset(y: side * 0.07)
                    PipSmile().stroke(Color(red: 0.06, green: 0.24, blue: 0.23), style: StrokeStyle(lineWidth: side * 0.024, lineCap: .round))
                        .frame(width: side * 0.13, height: side * 0.065).offset(y: side * 0.10)
                    Ellipse().fill(Color(red: 0.78, green: 0.92, blue: 0.36))
                        .frame(width: side * 0.14, height: side * 0.25).rotationEffect(.degrees(35))
                        .offset(x: side * 0.06, y: -side * 0.38)
                }.rotationEffect(.degrees(wave * 2))
                    .offset(y: -abs(wave) * side * 0.02)
                Image(systemName: "sparkle").font(.system(size: side * 0.14, weight: .medium))
                    .foregroundStyle(.teal).offset(x: side * 0.40, y: -side * 0.30)
            }.frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct PipSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.midX, y: rect.height * 1.8))
        return path
    }
}

struct MascotWaitingView: View {
    let title: String
    let detail: String
    var progress: Double?
    var cancelTitle: String?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                PipMascot(working: true)
                    .frame(width: 118, height: 118)

                Image(systemName: "clock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(9)
                    .background(.background, in: Circle())
                    .shadow(radius: 4, y: 2)
                    .offset(x: 4, y: -2)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let progress {
                ProgressView(value: progress)
                    .tint(.teal)
                    .frame(maxWidth: 220)
            } else {
                ProgressView()
            }

            if let cancelTitle, let onCancel {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: 300)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(radius: 24, y: 10)
    }
}

struct MascotWaitingPopup: View {
    let phase: String
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            MascotWaitingView(
                title: "Pip is working…",
                detail: phase,
                progress: progress,
                cancelTitle: "Cancel scan",
                onCancel: onCancel
            )
        }
    }
}

struct LoadingCompanion: View {
    let title: String
    var body: some View {
        MascotWaitingView(
            title: title,
            detail: "Pip is waiting for the photo to be ready.",
            progress: nil
        )
        .padding()
    }
}

