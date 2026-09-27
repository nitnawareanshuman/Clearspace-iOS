import SwiftUI

enum CollectionKind { case similar, screenshots }

struct PhotoCollectionView: View {
    let kind: CollectionKind
    @EnvironmentObject private var store: CleanerStore
    @State private var selected = Set<String>()
    @State private var draft: ReviewDraft?
    @State private var preview: PhotoItem?
    @State private var selectionNote: String?
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]
    private var title: String { kind == .similar ? "Similar photos" : "Screenshots" }
    private var items: [PhotoItem] {
        guard let result = store.result else { return [] }
        return kind == .similar ? result.groups.flatMap(\.items) : result.screenshots
    }
    private var selectedItems: [PhotoItem] { items.filter { selected.contains($0.id) } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if store.result == nil {
                    ScanAgainCompanion(title: "Ready for a fresh scan?",
                        detail: "Scan your current photo library to find things to review.")
                } else if items.isEmpty {
                    ScanAgainCompanion(title: kind == .similar ? "No similar photos left to review" : "No screenshots left to review",
                        detail: "You’re all caught up here. Scan again whenever you add more photos.")
                } else {
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(kind == .similar ? "Keep the moments you love." : "Let the temporary things go.").font(.title3.bold())
                            Text(kind == .similar
                                ? "These are suggestions, not guaranteed duplicates. Recommended keeps favor favorites, then resolution, then recency. Preview every group; keep at least one photo."
                                : "Tap screenshots to select them. Use the expand button to inspect details before you decide.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                Button(kind == .similar ? "Select suggestions" : "Select all") {
                                    if kind == .similar { selected = Set(store.result?.suggestions.map(\.id) ?? []) }
                                    else { selected = Set(store.result?.screenshotCandidates.map(\.id) ?? []) }
                                }
                                Spacer()
                                Button("Clear") { selected.removeAll() }.disabled(selected.isEmpty)
                            }.font(.subheadline.weight(.semibold))
                            if kind == .screenshots {
                                Text("Select all leaves one recommended keep in each matching group and skips read-only items.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if kind == .similar {
                        ForEach(store.result?.groups ?? []) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(group.visuallyIdentical ? "Matching previews" : "Similar moments").font(.headline)
                                    Spacer()
                                    Text("\(group.items.count) photos").font(.caption).foregroundStyle(.secondary)
                                }
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(group.items) { item in tile(item, keeper: item.id == group.keeperID) }
                                }
                            }
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(items) { item in tile(item) }
                        }
                    }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
            .safeAreaInset(edge: .bottom) {
                if !selectedItems.isEmpty {
                    VStack(spacing: 8) {
                        Text("\(selectedItems.count) selected · \(ByteSummary(selectedItems).label)")
                            .font(.subheadline.weight(.semibold))
                        Button { draft = store.makeDraft(selectedItems) } label: {
                            Text("Review selection").frame(maxWidth: .infinity).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent).disabled(store.busy)
                    }.padding().background(.regularMaterial)
                }
            }
            .sheet(item: $draft) { ReviewView(draft: $0) }
            .sheet(item: $preview) { PhotoPreview(item: $0) }
            .onChange(of: store.epoch) { _, _ in selected.removeAll() }
            .alert("Keep one photo", isPresented: Binding(get: { selectionNote != nil }, set: { if !$0 { selectionNote = nil } })) {
                Button("OK", role: .cancel) { selectionNote = nil }
            } message: { Text(selectionNote ?? "") }
    }
    private func tile(_ item: PhotoItem, keeper: Bool = false) -> some View {
        PhotoTile(item: item, selected: selected.contains(item.id), keeper: keeper) {
            if selected.contains(item.id) { selected.remove(item.id); return }
            let next = selected.union([item.id])
            if SelectionPolicy.allows(next, groups: store.result?.groups ?? []) { selected = next }
            else { selectionNote = "Leave at least one photo in each similar group unselected. You can choose a different photo to keep." }
        } preview: { preview = item }
    }
}

