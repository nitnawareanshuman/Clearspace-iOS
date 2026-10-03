import SwiftUI

/// Pip is drawn in SwiftUI, so it stays crisp at every size and needs no asset downloads.
struct PipMascot: View {
    var working = false
    var cleaning = false
    var animate = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0,
                                paused: !animate || reduceMotion || scenePhase != .active)) { timeline in
            // A bounded drawing transform cannot animate the surrounding layout or navigation.
            let animated = animate && !reduceMotion && scenePhase == .active
            let time = timeline.date.timeIntervalSinceReferenceDate
            let wave = animated ? sin(time * .pi * 2 / (working || cleaning ? 1.8 : 3.6)) : 0
            let blinkPhase = time.truncatingRemainder(dividingBy: 5.2)
            let eyeScale = animated && blinkPhase < 0.18 ? 0.15 : 1.0
            GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Ellipse().fill(.teal.opacity(0.14))
                    .frame(width: side * 0.62, height: side * 0.1).offset(y: side * 0.39)
                ZStack {
                    // A soft pebble, sprout, and broom make PipSweep's own companion.
                    Capsule().fill(.teal).frame(width: side * 0.17, height: side * 0.32)
                        .rotationEffect(.degrees(-32)).offset(x: -side * 0.34, y: side * 0.06)
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
                    }.scaleEffect(x: 1, y: eyeScale)
                        .foregroundStyle(Color(red: 0.06, green: 0.24, blue: 0.23)).offset(y: -side * 0.01)
                    HStack(spacing: side * 0.26) {
                        Ellipse().frame(width: side * 0.09, height: side * 0.04)
                        Ellipse().frame(width: side * 0.09, height: side * 0.04)
                    }.foregroundStyle(.pink.opacity(0.40)).offset(y: side * 0.07)
                    PipSmile().stroke(Color(red: 0.06, green: 0.24, blue: 0.23), style: StrokeStyle(lineWidth: side * 0.024, lineCap: .round))
                        .frame(width: side * 0.13, height: side * 0.065).offset(y: side * 0.10)
                    Ellipse().fill(Color(red: 0.78, green: 0.92, blue: 0.36))
                        .frame(width: side * 0.14, height: side * 0.25).rotationEffect(.degrees(35))
                        .offset(x: side * 0.06, y: -side * 0.38)
                    PipBroom()
                        .frame(width: side * 0.21, height: side * 0.72)
                        .rotationEffect(.degrees(8 + (cleaning ? wave * 9 : wave * 1.5)),
                                        anchor: UnitPoint(x: 0.5, y: 0.35))
                        .offset(x: side * 0.34, y: side * 0.04)
                    Circle().fill(.teal)
                        .frame(width: side * 0.15, height: side * 0.15)
                        .offset(x: side * 0.34, y: side * 0.10)
                }.rotationEffect(.degrees(wave * (working || cleaning ? 2 : 0.6)))
                    .offset(y: -wave * side * (working || cleaning ? 0.02 : 0.008))
                if cleaning {
                    Image(systemName: "sparkles")
                        .font(.system(size: side * 0.20, weight: .semibold))
                        .foregroundStyle(.teal)
                        .offset(x: -side * (0.28 + wave * 0.045), y: side * 0.25)
                        .opacity(0.7 + wave * 0.3)
                }
                Image(systemName: "sparkle").font(.system(size: side * 0.14, weight: .medium))
                    .foregroundStyle(.teal).offset(x: -side * 0.40, y: -side * 0.30)
            }.frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct PipBroom: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.86, green: 0.57, blue: 0.27),
                                                 Color(red: 0.67, green: 0.36, blue: 0.14)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * 0.19, height: height * 0.70)
                    .offset(y: -height * 0.13)
                PipBroomHead()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.83, blue: 0.38),
                                                 Color(red: 0.95, green: 0.66, blue: 0.24)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: width, height: height * 0.25)
                    .overlay {
                        PipBroomStrands()
                            .stroke(Color(red: 0.72, green: 0.42, blue: 0.13).opacity(0.55),
                                    style: StrokeStyle(lineWidth: width * 0.025, lineCap: .round))
                    }
                    .offset(y: height * 0.32)
                Capsule().fill(.teal)
                    .frame(width: width * 0.58, height: height * 0.045)
                    .offset(y: height * 0.225)
            }.frame(width: width, height: height)
        }
    }
}

private struct PipBroomHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.32, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.68, y: 0),
                          control: CGPoint(x: rect.midX, y: -rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.96, y: rect.height * 0.90))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.04, y: rect.height * 0.90),
                          control: CGPoint(x: rect.midX, y: rect.height * 1.12))
        path.closeSubpath()
        return path
    }
}

private struct PipBroomStrands: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<5 {
            let fraction = CGFloat(index) / 4
            path.move(to: CGPoint(x: rect.width * (0.36 + fraction * 0.28), y: rect.height * 0.16))
            path.addQuadCurve(to: CGPoint(x: rect.width * (0.13 + fraction * 0.74), y: rect.height * 0.88),
                              control: CGPoint(x: rect.width * (0.30 + fraction * 0.40), y: rect.height * 0.55))
        }
        return path
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
    var compact = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                PipMascot(working: true)
                    .frame(width: compact ? 76 : 118, height: compact ? 76 : 118)

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
        .padding(compact ? 14 : 24)
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
            detail: "Pip is getting things ready.",
            progress: nil,
            compact: true
        )
        .padding()
    }
}


struct MascotEmptyState: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            PipMascot().frame(width: 120, height: 120)
            Text(title).font(.title3.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

struct MascotMessageView: View {
    let message: String
    let onDone: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PipMascot().frame(width: 132, height: 132)
                Text("A little more breathing room").font(.title2.bold())
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }.multilineTextAlignment(.center).padding(24).frame(maxWidth: .infinity)
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}


/// Shared empty state keeps rescanning available within the current category.
struct ScanAgainCompanion: View {
    let title: String
    let detail: String
    @EnvironmentObject private var store: CleanerStore
    var body: some View {
        VStack(spacing: 18) {
            PipMascot(working: store.scanning).frame(width: 160, height: 170)
            Text(store.scanning ? "Pip is finding room…" : title).font(.title2.bold())
            Text(store.scanning ? store.phase : detail)
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            if store.scanning {
                ProgressView(value: store.progress)
                Button("Cancel scan") { store.cancelScan() }
            } else {
                Button("Scan again") { store.startScan() }
                    .buttonStyle(.borderedProminent).disabled(store.busy || !store.hasAccess)
                if !store.hasAccess {
                    Text("Return to the dashboard to allow Photos access.").font(.footnote)
                }
            }
        }.padding(24).frame(maxWidth: .infinity)
    }
}

struct CleanupFeedback: View {
    let completed: Bool
    let title: String
    let detail: String
    let done: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 18) {
                PipMascot(working: !completed, cleaning: true).frame(width: 150, height: 160)
                Text(title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if completed {
                    Button("Continue", action: done).buttonStyle(.borderedProminent)
                } else { ProgressView() }
            }.padding(28).frame(maxWidth: 350)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                .padding(20)
        }.accessibilityAddTraits(.isModal)
    }
}
