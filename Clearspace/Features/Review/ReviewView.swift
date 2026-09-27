import SwiftUI

struct ReviewView: View {
    let draft: ReviewDraft
    @EnvironmentObject private var store: CleanerStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var completed = false
    @State private var error: String?
    @State private var preview: PhotoItem?
    private var stale: Bool { draft.epoch != store.epoch || !store.hasAccess }
    private var favorites: Int { draft.items.filter(\.favorite).count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("One last look", systemImage: "hand.raised.fill").font(.title2.bold())
                            Text("\(draft.items.count) items · estimated savings: \(ByteSummary(draft.items).label)").font(.headline)
                            Text("Only the items shown below will be requested for deletion. Cancel to change your selection.")
                            Text("Photos moves deleted items to Recently Deleted for up to 30 days. Space may not be freed immediately. With iCloud Photos enabled, deletion syncs to your other devices.")
                                .font(.footnote).foregroundStyle(.secondary)
                            if favorites > 0 {
                                Label("Your selection includes \(favorites) favorites.", systemImage: "heart.fill")
                                    .foregroundStyle(.orange).font(.subheadline.bold())
                            }
                            if ByteSummary(draft.items).unknown > 0 {
                                Text("Some sizes are unavailable. The total excludes unknown bytes.").font(.footnote)
                            }
                            Text("Resource sizes are estimates of the selected library content, not a promise of reclaimed device storage.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if stale {
                        Label("The library or your access changed. Cancel and scan again before deleting.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 14) {
                        ForEach(draft.items) { item in
                            Button { preview = item } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    PhotoThumbnail(item: item).frame(height: 160)
                                        .overlay { if item.video { Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white) } }
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(item.created?.formatted(date: .abbreviated, time: .shortened) ?? "Date unavailable")
                                        .font(.caption)
                                    Text(ByteSummary([item]).label).font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain).accessibilityLabel(item.video ? "Play selected video" : "Preview selected photo")
                        }
                    }
                    if !draft.kept.isEmpty {
                        Text("WILL BE KEPT").font(.caption.bold()).foregroundStyle(.teal)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 14) {
                            ForEach(draft.kept) { item in
                                Button { preview = item } label: {
                                    PhotoThumbnail(item: item).frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(alignment: .bottom) {
                                            Label("Keep", systemImage: "checkmark.shield.fill")
                                                .padding(6).background(.regularMaterial, in: Capsule()).padding(6)
                                        }
                                }.buttonStyle(.plain).accessibilityLabel("Preview photo that will be kept")
                            }
                        }
                    }
                }.padding(20)
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Review deletion").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(store.deleting)
                } }
                .safeAreaInset(edge: .bottom) {
                    Button(role: .destructive) { confirm = true } label: {
                        HStack {
                            if store.deleting { ProgressView() }
                            Text(store.deleting ? "Waiting for Photos…" : "Delete \(draft.items.count) items")
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).tint(.red).padding().background(.regularMaterial)
                        .disabled(stale || store.busy)
                }
                .confirmationDialog("Delete \(draft.items.count) reviewed items?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Delete reviewed items", role: .destructive) {
                        Task {
                            do { try await store.delete(draft); completed = true }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    Button("Keep everything", role: .cancel) { }
                } message: { Text("iOS will ask for permission next. Nothing is removed if you cancel either step.") }
                .alert("Nothing confirmed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
                .sheet(item: $preview) { PhotoPreview(item: $0) }
                .interactiveDismissDisabled(store.deleting || completed)
                .overlay {
                    if store.deleting || completed {
                        CleanupFeedback(completed: completed,
                            title: completed ? "A little less clutter!" : "Pip is clearing things up…",
                            detail: completed
                                ? "Removed \(draft.items.count) items. They remain in Recently Deleted until Photos removes them permanently. Continue to review what’s left."
                                : "Waiting for Photos to finish your approved cleanup.",
                            done: { dismiss() })
                    }
                }
        }
    }
}

