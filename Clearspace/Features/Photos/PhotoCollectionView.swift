import SwiftUI

enum CollectionKind { case similar, screenshots }

struct PhotoCollectionView: View {
    let kind: CollectionKind
    @EnvironmentObject private var store: CleanerStore
    @State private var selected = Set<String>()
    @State private var draft: ReviewDraft?
    @State private var preview: PhotoItem?
    @State private var selectionNote: String?
    @State private var swipeMode = false
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
                    ContentUnavailableView("Scan needed", systemImage: "arrow.clockwise",
                        description: Text("Return to Clearspace and scan your current photo library."))
                } else if items.isEmpty {
                    ContentUnavailableView(kind == .similar ? "No similar groups found" : "No screenshots found",
                        systemImage: "checkmark.seal", description: Text("Results cover the photos available to Clearspace on this device."))
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
                } else {
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(kind == .similar ? "Keep the moments you love." : "Let the temporary things go.")
                                        .font(.title3.bold())
                                    Text(kind == .similar
                                        ? "These are suggestions, not guaranteed duplicates. Recommended keeps favor favorites, then resolution, then recency. Preview every group; keep at least one photo."
                                        : "Tap screenshots to select them. Use the expand button to inspect details before you decide.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Button { swipeMode = true } label: {
                                    Label("Swipe mode", systemImage: "hand.draw")
                                }.buttonStyle(.bordered)
                            }
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
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
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
    @State private var dragOffset: CGSize = .zero
    @State private var decisionNotice: String?

    private var current: PhotoItem? {
        guard index < items.count else { return nil }
        return items[index]
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe to decide").font(.title2.bold())
                    Text("Right = keep · Left = queue for deletion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Exit") { onExit() }.buttonStyle(.bordered)
            }

            Text("\(max(0, items.count - index)) photos left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let item = current {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    PhotoThumbnail(item: item, large: true)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                    if abs(dragOffset.width) > 25 {
                        Text(dragOffset.width > 0 ? "KEEP" : "DELETE")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(dragOffset.width > 0 ? .teal : .red)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .rotationEffect(.degrees(dragOffset.width > 0 ? 7 : -7))
                    }

                    VStack {
                        HStack {
                            if item.favorite {
                                Label("Favorite", systemImage: "heart.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.35), in: Capsule())
                            }
                            Spacer()
                            Text(ByteSummary([item]).label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.35), in: Capsule())
                        }

                        Spacer()

                        HStack {
                            Label("Delete", systemImage: "arrow.left")
                                .foregroundStyle(.white)
                            Spacer()
                            Label("Keep", systemImage: "arrow.right")
                                .foregroundStyle(.white)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(12)
                        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .offset(x: dragOffset.width)
                .rotationEffect(.degrees(Double(dragOffset.width) / 24))
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in dragOffset = value.translation }
                        .onEnded { value in
                            let threshold: CGFloat = 110
                            if value.translation.width > threshold {
                                decide(.keep)
                            } else if value.translation.width < -threshold {
                                decide(.delete)
                            } else {
                                resetCard()
                            }
                        }
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                    value: dragOffset
                )

                HStack(spacing: 24) {
                    Button { decide(.delete) } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                            .frame(width: 58, height: 58)
                            .background(.red.opacity(0.12), in: Circle())
                    }
                    .tint(.red)
                    .disabled(!item.canDelete)
                    .accessibilityLabel("Queue this photo for deletion")

                    Button { decide(.keep) } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .frame(width: 58, height: 58)
                            .background(.teal.opacity(0.12), in: Circle())
                    }
                    .tint(.teal)
                    .accessibilityLabel("Keep this photo")

                    Button("Review \(selected.count)") { onReview() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
                }
            } else {
                Surface {
                    VStack(spacing: 10) {
                        PipMascot().frame(width: 110, height: 110)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.teal)
                        Text("You're all caught up").font(.title2.bold())
                        Text("\(selected.count) photo(s) queued for review.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Button("Back to grid") { onExit() }.buttonStyle(.bordered)
                    Spacer()
                    Button("Review deletion") { onReview() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
                }
            }

            if let decisionNotice {
                Text(decisionNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Nothing is deleted while swiping. Your choices go to the normal review screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }

    private enum Decision {
        case keep
        case delete
    }

    private func decide(_ decision: Decision) {
        guard let item = current else { return }

        if decision == .delete && !item.canDelete {
            decisionNotice = "This item is read-only and cannot be queued for deletion."
            goNext()
            return
        }

        if decision == .delete {
            let proposed = selected.union([item.id])
            if !SelectionPolicy.allows(proposed, groups: groups) {
                decisionNotice = "Keep at least one photo from each similar group. This photo must stay."
                resetCard()
                return
            }
        }

        switch decision {
        case .keep:
            selected.remove(item.id)
        case .delete:
            selected.insert(item.id)
        }

        goNext()
    }

    private func resetCard() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            dragOffset = .zero
        }
    }

    private func goNext() {
        decisionNotice = nil

        if reduceMotion {
            dragOffset = .zero
            index += 1
            return
        }

        let direction: CGFloat = dragOffset.width < 0 ? -1 : 1
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            dragOffset = .init(width: direction * 520, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            index += 1
        }
    }
}
