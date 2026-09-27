import SwiftUI
import Photos
import AVKit

struct VideoCollectionView: View {
    @EnvironmentObject private var store: CleanerStore
    @State private var selected = Set<String>()
    @State private var preview: PhotoItem?
    @State private var draft: ReviewDraft?
    private var videos: [PhotoItem] { store.result?.videos ?? [] }
    private var selection: [PhotoItem] { videos.filter { selected.contains($0.id) } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Big memories. Your choice.").font(.title2.bold())
                        Text("All accessible videos, largest first. Unknown sizes appear last. Play a video before choosing to remove it.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Select non-favorites") { selected = Set(videos.filter { !$0.favorite && $0.canDelete }.map(\.id)) }
                            Spacer()
                            Button("Clear") { selected.removeAll() }.disabled(selected.isEmpty)
                        }.font(.subheadline)
                    }
                }
                if store.result == nil {
                    MascotEmptyState(title: "Ready for a fresh look?", detail: "Return home and scan your library again.")
                } else if videos.isEmpty {
                    ContentUnavailableView("No videos found", systemImage: "video", description: Text("Results cover the library you allow Clearspace to access."))
                }
                ForEach(videos) { item in
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { preview = item } label: {
                                PhotoThumbnail(item: item).frame(height: 190)
                                    .overlay { Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white).shadow(radius: 8) }
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain).accessibilityLabel("Play video")
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ByteSummary([item]).label).font(.title3.bold())
                                    Text("\(Int(item.duration) / 60)m \(Int(item.duration) % 60)s · \(item.created?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date")")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if item.favorite { Label("Favorite", systemImage: "heart.fill").font(.caption).foregroundStyle(.pink) }
                                    if !item.canDelete { Text("Read-only · cannot delete here").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Button {
                                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                                } label: {
                                    Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title).frame(width: 48, height: 48)
                                }.accessibilityLabel("Select video, \(ByteSummary([item]).label)")
                                    .accessibilityValue(selected.contains(item.id) ? "Selected" : "Not selected")
                                    .disabled(!item.canDelete)
                            }
                        }
                    }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Large videos")
            .safeAreaInset(edge: .bottom) {
                if !selection.isEmpty {
                    Button { draft = store.makeDraft(selection) } label: {
                        Text("Review \(selection.count) · \(ByteSummary(selection).label)").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).padding().background(.regularMaterial).disabled(store.busy)
                }
            }
            .sheet(item: $preview) { VideoPreview(item: $0) }
            .sheet(item: $draft) { ReviewView(draft: $0) }
            .onChange(of: store.epoch) { _, _ in selected.removeAll() }
    }
}

struct VideoPreview: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let player { VideoPlayer(player: player) }
                else if let error { ContentUnavailableView("Video unavailable", systemImage: "icloud.slash", description: Text(error)) }
                else { LoadingCompanion(title: "Preparing your video…") }
                Text(ByteSummary([item]).label).font(.headline)
                Text("Playback stays on your iPhone. Cloud-only videos are not downloaded.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }.navigationTitle("Video preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task(id: item.id) {
                    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject else {
                        error = "This video is no longer accessible."; return
                    }
                    do {
                        let loaded = try await PhotoRequests.playerItem(for: asset)
                        try Task.checkCancellation()
                        player = AVPlayer(playerItem: loaded)
                    } catch is CancellationError { }
                    catch { self.error = error.localizedDescription }
                }
                .onDisappear { player?.pause(); player = nil }
        }
    }
}
