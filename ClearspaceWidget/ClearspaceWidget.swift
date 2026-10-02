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
            Label("PipSweep", systemImage: "sparkles").font(.headline).foregroundStyle(.teal)
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
