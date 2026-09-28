import SwiftUI

enum CollectionKind { case similar, screenshots, blurry }

struct PhotoCollectionView: View {
    let kind: CollectionKind
    @EnvironmentObject private var store: CleanerStore
    @State private var selected = Set<String>()
    @State private var draft: ReviewDraft?
    @State private var preview: PhotoItem?
    @State private var selectionNote: String?
    @State private var swipeMode = false
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]
    private var title: String {
        switch kind {
        case .similar: return "Similar photos"
        case .screenshots: return "Screenshots"
        case .blurry: return "Blurry photos"
        }
    }
    private var emptyTitle: String {
        switch kind {
        case .similar: return "No similar groups found"
        case .screenshots: return "No screenshots found"
        case .blurry: return "No likely blurry photos found"
        }
    }
    private var guidance: String {
        switch kind {
        case .similar:
            return "These are suggestions, not guaranteed duplicates. Recommended keeps favor favorites, then resolution, then recency. Preview every group; keep at least one photo."
        case .screenshots:
            return "Tap screenshots to select them. Use the expand button to inspect details before you decide."
        case .blurry:
            return "These photos may be blurry. Intentional soft focus can appear here too. Preview each photo before deciding; nothing is selected automatically. Select suggestions skips favorites, read-only items and the last copy in a similar group."
        }
    }
    private var items: [PhotoItem] {
        guard let result = store.result else { return [] }
        switch kind {
        case .similar: return SelectionPolicy.unique(result.groups.flatMap(\.items))
        case .screenshots: return SelectionPolicy.unique(result.screenshots)
        case .blurry: return SelectionPolicy.unique(result.blurryPhotos)
        }
    }
    private var selectedItems: [PhotoItem] { items.filter { selected.contains($0.id) } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if store.result == nil {
                    ScanAgainCompanion(title: "Ready for a fresh scan?", detail: "Scan your current photo library to find things to review.")
                } else if items.isEmpty {
                    ScanAgainCompanion(title: emptyTitle,
                        detail: kind == .blurry
                            ? "No blur suggestions among assessable photos. Screenshots, unavailable photos and images with too little detail are skipped."
                            : "You’re all caught up here. Scan again whenever you add more photos.")
                } else if swipeMode {
                    SwipeReviewView(
                        items: items,
                        groups: store.result?.groups ?? [],
                        selected: $selected,
                        onExit: { swipeMode = false },
                        onReview: {
                            guard !selected.isEmpty else { swipeMode = false; return }
                            draft = store.makeDraft(selectedItems)
                        }
                    )
                    .id(store.epoch)
                } else {
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(kind == .blurry ? "Find the moments worth keeping." : (kind == .similar ? "Keep the moments you love." : "Let the temporary things go."))
                                        .font(.title3.bold())
                                    Text(guidance)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Button { swipeMode = true } label: {
                                    Label("Swipe mode", systemImage: "hand.draw")
                                }.buttonStyle(.bordered)
                            }
                            HStack {
                                Button(kind == .screenshots ? "Select all" : "Select suggestions") {
                                    if kind == .similar { selected = Set(store.result?.suggestions.map(\.id) ?? []) }
                                    else if kind == .blurry { selected = Set(store.result?.blurryCandidates.map(\.id) ?? []) }
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
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !swipeMode && !items.isEmpty {
                    Button { swipeMode = true } label: {
                        Image(systemName: "hand.draw").accessibilityLabel("Open swipe-to-keep-or-delete mode")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedItems.isEmpty && !swipeMode {
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
            guard item.canDelete else { return }
            if selected.contains(item.id) { selected.remove(item.id); return }
            let next = selected.union([item.id])
            if SelectionPolicy.allows(next, groups: store.result?.groups ?? []) {
                selected = next
            } else {
                selectionNote = "Leave at least one photo in each similar group unselected. You can choose a different photo to keep."
            }
        } preview: { preview = item }
    }
}

private struct SwipeReviewView: View {
    let items: [PhotoItem]
    let groups: [PhotoGroup]
    @Binding var selected: Set<String>
    let onExit: () -> Void
    let onReview: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var offset: CGFloat = 0
    @State private var pending: SwipeDecision?
    @State private var history: [SwipeHistoryEntry] = []
    @State private var notice: String?
    @State private var preview: PhotoItem?

    private var current: PhotoItem? { items.indices.contains(index) ? items[index] : nil }
    private var queued: [PhotoItem] { items.filter { selected.contains($0.id) } }
    private var transitioning: Bool { pending != nil }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A little less clutter").font(.title2.bold())
                    Text("Left to remove. Right to keep.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Grid", action: onExit).buttonStyle(.bordered)
                    .disabled(transitioning)
            }
            VStack(spacing: 8) {
                ProgressView(value: Double(index), total: Double(max(items.count, 1))).tint(.teal)
                HStack {
                    Text("\(index) of \(items.count) reviewed")
                    Spacer()
                    Text("\(queued.count) queued")
                }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }

            if let item = current {
                card(item)
                HStack(spacing: 12) {
                    Button { decide(.delete) } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered).tint(.red)
                        .disabled(!item.canDelete || transitioning)
                        .accessibilityLabel("Queue photo for deletion")
                    Button { decide(.keep) } label: {
                        Label("Keep", systemImage: "heart")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.borderedProminent).tint(.teal).disabled(transitioning)
                }
            } else {
                MascotEmptyState(title: "All reviewed!", detail: queued.isEmpty
                    ? "Every photo is staying. A little peace of mind."
                    : "Your choices are ready. Take one last look before deleting anything.")
            }

            if let notice {
                Label(notice, systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(history.isEmpty || transitioning)
                Spacer()
                if let item = current {
                    Button { preview = item } label: {
                        Label("Preview", systemImage: "arrow.up.left.and.arrow.down.right")
                    }.disabled(transitioning)
                }
            }.buttonStyle(.bordered)

            Button(action: onReview) {
                VStack(spacing: 4) {
                    Text("Review \(queued.count) photos").font(.headline)
                    Text(ByteSummary(queued).label).font(.caption)
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderedProminent).disabled(queued.isEmpty || transitioning)
            Text("Swiping only makes a selection. Nothing is deleted until you review and confirm.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .sheet(item: $preview) { PhotoPreview(item: $0) }
        // Cancellation belongs to the view's lifetime. A departing card cannot advance a new session.
        .task(id: pending) {
            guard let decision = pending else { return }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) { offset = decision == .delete ? -600 : 600 }
                do { try await Task.sleep(for: .milliseconds(220)) }
                catch { return }
            }
            guard !Task.isCancelled, pending == decision else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                index += 1
                offset = 0
                pending = nil
            }
        }
    }

    private func card(_ item: PhotoItem) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                PhotoThumbnail(item: item, large: true)
                    .id(item.id)
                VStack {
                    HStack {
                        if item.favorite { badge("Favorite", icon: "heart.fill") }
                        Spacer()
                        if groups.contains(where: { $0.keeperID == item.id }) {
                            badge("Suggested keep", icon: "checkmark.shield")
                        }
                    }
                    Spacer()
                    HStack {
                        Text(item.created?.formatted(date: .abbreviated, time: .omitted) ?? "Photo")
                        Spacer()
                        Text(ByteSummary([item]).label)
                    }.font(.caption.weight(.semibold))
                        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    if !item.canDelete {
                        badge("Read-only · keep or skip this photo", icon: "lock")
                    } else if selected.contains(item.id) {
                        badge("Already queued · keep to unselect", icon: "tray")
                    }
                }.padding(12)
                if abs(offset) > 25 {
                    Text(offset > 0 ? "KEEP" : "REMOVE")
                        .font(.title.bold()).foregroundStyle(offset > 0 ? Color.teal : Color.red)
                        .padding().background(.regularMaterial, in: Capsule())
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .offset(x: reduceMotion ? 0 : offset)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 30)))
            .gesture(DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard !transitioning, abs(value.translation.width) > abs(value.translation.height) else { return }
                    offset = value.translation.width
                }
                .onEnded { value in
                    guard !transitioning else { return }
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    let threshold = min(CGFloat(100), proxy.size.width * 0.28)
                    if horizontal && abs(value.translation.width) >= threshold {
                        decide(value.translation.width > 0 ? .keep : .delete)
                    } else { resetCard() }
                })
            .accessibilityAction(named: Text("Keep photo")) { decide(.keep) }
            .accessibilityAction(named: Text("Queue for deletion")) { decide(.delete) }
        }
        .frame(height: 340)
        .clipped()
    }

    private func badge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption2.weight(.semibold))
            .padding(8).background(.regularMaterial, in: Capsule())
    }

    private func decide(_ decision: SwipeDecision) {
        guard !transitioning, let item = current else { return }
        if let reason = SwipePolicy.blockReason(decision, item: item, selected: selected, groups: groups) {
            notice = reason
            resetCard()
            return
        }
        notice = nil
        history.append(SwipeHistoryEntry(index: index, id: item.id, wasSelected: selected.contains(item.id)))
        selected = SwipePolicy.applying(decision, id: item.id, to: selected)
        pending = decision // Locks both gesture and buttons synchronously, before animation starts.
    }

    private func undo() {
        guard !transitioning, let entry = history.popLast() else { return }
        selected = SwipePolicy.restoring(entry, in: selected)
        index = entry.index
        notice = nil
        offset = 0
    }

    private func resetCard() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85)) { offset = 0 }
    }
}
