import SwiftUI
import Photos
import UIKit
import PhotosUI

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct PhotoThumbnail: View {
    let item: PhotoItem
    var large = false
    @State private var image: UIImage?
    @State private var unavailable = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: .tertiarySystemFill)
                if let image {
                    Image(uiImage: image).resizable()
                        .aspectRatio(contentMode: large ? .fit : .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else if unavailable {
                    VStack(spacing: 6) {
                        Image(systemName: "icloud.slash")
                        if large { Text("Preview unavailable on this device").font(.footnote) }
                    }.foregroundStyle(.secondary)
                } else {
                    if large { LoadingCompanion(title: "Preparing your photo…") }
                    else { ProgressView() }
                }
            }
        }
        .task(id: item.id) {
            image = nil
            unavailable = false
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject else {
                unavailable = true; return
            }
            do {
                let loaded = try await PhotoRequests.image(for: asset, side: large ? 1400 : 300)
                try Task.checkCancellation()
                image = loaded
            }
            catch is CancellationError { }
            catch { unavailable = true }
        }
    }
}

struct PhotoPreview: View {
    let item: PhotoItem
    var body: some View {
        if item.video { VideoPreview(item: item) }
        else { StillPhotoPreview(item: item) }
    }
}

struct StillPhotoPreview: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotoThumbnail(item: item, large: true)
                Text(item.created?.formatted(date: .abbreviated, time: .shortened) ?? "Date unavailable")
                Text("\(item.width) × \(item.height) · \(ByteSummary([item]).label)")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding().navigationTitle("Photo preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct PhotoTile: View {
    let item: PhotoItem
    let selected: Bool
    var keeper = false
    let toggle: () -> Void
    let preview: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) {
                PhotoThumbnail(item: item).frame(height: 155)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(selected ? Color.teal : .white)
                            .padding(8).background(.black.opacity(0.35), in: Circle()).padding(6)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if keeper { Text("Recommended keep").font(.caption2.bold()).padding(6)
                            .background(.ultraThinMaterial, in: Capsule()).padding(6) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.teal : .clear, lineWidth: 3))
            }.buttonStyle(.plain).disabled(!item.canDelete)
                .accessibilityLabel("\(item.screenshot ? "Screenshot" : "Photo"), \(item.created?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")\(item.favorite ? ", favorite" : "")\(keeper ? ", recommended keep" : "")")
                .accessibilityValue(selected ? "Selected for review" : "Not selected")
                .accessibilityHint("Double tap to change selection")
            HStack {
                if item.favorite { Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("Favorite") }
                Text(ByteSummary([item]).label).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(action: preview) { Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Preview photo")
            }
            if !item.canDelete { Text("Read-only · cannot delete here").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct LimitedLibraryPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { PickerController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
    private final class PickerController: UIViewController {
        private var presented = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !presented else { return }
            presented = true
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
        }
    }
}
