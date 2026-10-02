import SwiftUI

struct TidySessionView: View {
    @EnvironmentObject private var store: CleanerStore
    @Environment(\.dismiss) private var dismiss
    @State private var batch: [PhotoItem] = []
    @State private var selected = Set<String>()
    @State private var reviewedIDs = Set<String>()
    @State private var reviewedCount = 0
    @State private var batchID = UUID()
    @State private var draft: ReviewDraft?

    private var selectedItems: [PhotoItem] { batch.filter { selected.contains($0.id) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Surface {
                    HStack(alignment: .center, spacing: 16) {
                        PipMascot(cleaning: true).frame(width: 82, height: 88)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ten small choices. A little more room.").font(.headline)
                            Text("Review up to ten screenshots, oldest first. Favorites are skipped. Keep anything useful.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if store.result == nil {
                    ScanAgainCompanion(title: "Let's find a few things to tidy.",
                                       detail: "Scan the photos available on your iPhone to prepare your next small session.")
                } else if batch.isEmpty {
                    MascotEmptyState(title: "A good place to pause",
                                     detail: reviewedIDs.isEmpty
                                         ? "There are no eligible screenshots for a session. You can review other categories on the dashboard."
                                         : "You've reviewed the available screenshots in this session. Everything you kept is staying.")
                    Button("Back to dashboard") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    SwipeReviewView(
                        items: batch,
                        groups: store.result?.groups ?? [],
                        selected: $selected,
                        onExit: { dismiss() },
                        onReview: { draft = store.makeDraft(selectedItems) },
                        exitTitle: "Done",
                        onProgress: { reviewedCount = $0 }
                    ).id(batchID)
                    if reviewedCount == batch.count && selected.isEmpty {
                        Button {
                            markReviewed()
                            loadBatch()
                        } label: {
                            Label("Next ten screenshots", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent).disabled(store.busy)
                    }
                }
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Pip's ten-shot tidy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $draft) { ReviewView(draft: $0) }
        .onAppear { loadBatch() }
        .onChange(of: store.epoch) { _, _ in
            // Only successful deletion preserves a result while changing the epoch.
            // Retain reviewed decisions for this visit, never a stale delete selection.
            if store.result != nil { markReviewed() }
            else { reviewedIDs.removeAll() }
            loadBatch()
        }
        .onChange(of: store.result == nil) { _, missing in
            if missing { reviewedIDs.removeAll() }
            loadBatch()
        }
    }

    private func markReviewed() {
        reviewedIDs.formUnion(batch.prefix(reviewedCount).map(\.id))
    }

    private func loadBatch() {
        selected.removeAll()
        reviewedCount = 0
        batchID = UUID()
        batch = store.result.map { TidySessionPolicy.candidates(from: $0, excluding: reviewedIDs) } ?? []
    }
}
