import SwiftUI
import WidgetKit

struct StorageEntry: TimelineEntry {
    let date: Date
    let total: Int64?
    let free: Int64?
    static func read() -> StorageEntry {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        return StorageEntry(date: Date(), total: values?.volumeTotalCapacity.map { Int64($0) },
                            free: values?.volumeAvailableCapacity.map { Int64($0) })
    }
}

struct StorageProvider: TimelineProvider {
    func placeholder(in context: Context) -> StorageEntry {
        StorageEntry(date: Date(), total: 128_000_000_000, free: 32_000_000_000)
    }
    func getSnapshot(in context: Context, completion: @escaping (StorageEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : .read())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageEntry>) -> Void) {
        completion(Timeline(entries: [.read()], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct StorageWidgetView: View {
    let entry: StorageEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                WidgetPipIcon().frame(width: 34, height: 36)
                Text("PipSweep").font(.headline).foregroundStyle(.teal)
            }
            if let total = entry.total, let free = entry.free, total > 0 {
                Text(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))
                    .font(.system(size: 30, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text("available").font(.caption).foregroundStyle(.secondary)
                ProgressView(value: min(1, max(0, Double(total - free) / Double(total)))).tint(.teal)
                if family == .systemMedium {
                    Text("\(ByteCountFormatter.string(fromByteCount: max(0, total - free), countStyle: .file)) used of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Storage unavailable").font(.headline)
                Text("Open PipSweep to try again.").font(.caption)
            }
            HStack(spacing: 4) {
                Text("Updated")
                Text(entry.date, style: .time)
            }.font(.caption2).foregroundStyle(.secondary)
            #if targetEnvironment(simulator)
            Text("Simulator · Mac storage").font(.caption2).foregroundStyle(.secondary)
            #endif
        }.containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ClearspaceStorageWidget: Widget {
    let kind = "ClearspaceStorageWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StorageProvider()) { StorageWidgetView(entry: $0) }
            .configurationDisplayName("PipSweep Storage")
            .description("See available device storage at a glance. Tap to open PipSweep.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}



/// Static Pip artwork for WidgetKit; no animation timeline or app dependencies.
private struct WidgetPipIcon: View {
    var working = false
    var cleaning = false

    var body: some View {
        let wave = 0.0
        let eyeScale = 1.0
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
