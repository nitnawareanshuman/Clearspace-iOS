import SwiftUI

struct SpaceFreedView: View {
    var receipt: CleanupReceipt? = nil
    var done: (() -> Void)? = nil
    @ObservedObject private var history = CleanupHistory.shared
    private var entries: [CleanupReceipt] { receipt.map { [$0] } ?? history.receipts }
    private var bytes: Int64 { entries.reduce(0) { $0 + $1.estimatedBytes } }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                PipMascot().frame(width: 145, height: 150)
                Text(entries.isEmpty ? "Your next fresh start" : "A little more breathing room")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("Estimated media removed").font(.headline)
                        Text("\(entries.reduce(0) { $0 + $1.itemCount }) items cleaned\(receipt == nil ? " since tracking began" : " in this cleanup")")
                        if entries.contains(where: { $0.unknownSizes > 0 }) {
                            Text("Some media sizes were unavailable and are excluded from the estimate.").font(.footnote)
                        }
                        Text("Photos keeps deleted media in Recently Deleted for up to 30 days. This estimate is not a measurement of device space freed. Restoring media does not undo this activity history.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Calendar and contact cleanup count items only; their storage sizes are unavailable.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if entries.isEmpty {
                    Text("Review and complete a cleanup to see your results here. Cancelled and failed actions do not count.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                ForEach(entries) { entry in
                    Surface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            if entry.photos > 0 { Label("\(entry.photos) photos removed", systemImage: "photo") }
                            if entry.videos > 0 { Label("\(entry.videos) videos removed", systemImage: "video") }
                            if entry.contacts > 0 { Label("\(entry.contacts) contacts removed", systemImage: "person.crop.circle") }
                            if entry.events > 0 { Label("\(entry.events) calendar events removed", systemImage: "calendar") }
                        }
                    }
                }
                if let done { Button("Done", action: done).buttonStyle(.borderedProminent) }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Space freed").navigationBarTitleDisplayMode(.inline)
    }
}
