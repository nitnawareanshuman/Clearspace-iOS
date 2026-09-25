import SwiftUI
import Photos

struct DashboardView: View {
    @EnvironmentObject private var store: CleanerStore
    @Environment(\.openURL) private var openURL
    @State private var showLimitedPicker = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        BrandMark()
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Clearspace").font(.title2.bold())
                            Text("Room for what matters.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    storageCard
                    permissionCard
                    if store.hasAccess {
                        scanCard
                        if let result = store.result {
                            Text("YOUR LIBRARY").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                            NavigationLink {
                                PhotoCollectionView(kind: .similar)
                            } label: {
                                category("Similar photos", subtitle: "\(result.groups.count) groups · keep your favorites",
                                    icon: "square.on.square", summary: ByteSummary(result.suggestions).label, color: .teal)
                            }.buttonStyle(.plain)
                            NavigationLink {
                                PhotoCollectionView(kind: .screenshots)
                            } label: {
                                category("Screenshots", subtitle: "\(result.screenshots.count) screenshots to review",
                                    icon: "viewfinder", summary: ByteSummary(result.screenshots).label, color: .indigo)
                            }.buttonStyle(.plain)
                            Surface {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("About these estimates", systemImage: "info.circle").font(.subheadline.bold())
                                    Text("Sizes count available photo resources, not guaranteed free device space. Similar-photo estimates exclude recommended keeps and favorites. Screenshot totals include all screenshots; choose what you no longer need.")
                                    if result.unavailable > 0 {
                                        Text("\(result.unavailable) photos could not be analyzed locally. Cloud-only items are not downloaded.")
                                    }
                                    if result.unmeasured > 0 {
                                        Text("\(result.unmeasured) candidate sizes are unavailable and excluded from byte totals.")
                                    }
                                }.font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Surface {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Coming in the next milestone").font(.subheadline.bold())
                                Label("Large videos", systemImage: "video")
                                Label("Duplicate contacts", systemImage: "person.2")
                                Text("These categories are not scanned yet.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Label("Private by design. Processed on your iPhone.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(20)
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showLimitedPicker, onDismiss: { store.refreshAccess() }) {
                    NavigationStack {
                        LimitedLibraryPicker().navigationTitle("Photos access")
                            .toolbar { ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showLimitedPicker = false }
                            } }
                    }
                }
                .alert("Clearspace", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("OK", role: .cancel) { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
    }
    private var storageCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 18) {
                Text("A LITTLE BREATHING ROOM").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.teal)
                if let storage = store.storage {
                    Text(ByteCountFormatter.string(fromByteCount: storage.free, countStyle: .file))
                        .font(.system(size: 44, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("free on your iPhone").foregroundStyle(.secondary)
                    ProgressView(value: storage.fraction).tint(.teal)
                        .accessibilityLabel("Device storage used").accessibilityValue("\(Int(storage.fraction * 100)) percent")
                    Text("\(ByteCountFormatter.string(fromByteCount: storage.used, countStyle: .file)) used of \(ByteCountFormatter.string(fromByteCount: storage.total, countStyle: .file))")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Storage unavailable").font(.title2.bold())
                    Text(store.storageError ?? "Try refreshing.").font(.footnote)
                    Button("Refresh storage") { store.refreshStorage() }
                }
            }
        }
    }
    @ViewBuilder private var permissionCard: some View {
        if !store.hasAccess {
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Your photos, your choice", systemImage: "photo.badge.checkmark").font(.headline)
                    Text("Allow Photos access to find similar shots and screenshots. Everything is analyzed on this iPhone. You review each selection before iOS asks you to confirm deletion.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if store.authorization == .notDetermined {
                        Button("Choose Photos access") { Task { await store.requestAccess() } }
                            .buttonStyle(.borderedProminent)
                    } else if store.authorization == .restricted {
                        Text("Photos access is restricted by this device’s settings. Ask the device administrator to allow access.").font(.footnote)
                    } else {
                        Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        } else if store.authorization == .limited {
            Surface {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Limited Photos access", systemImage: "photo.on.rectangle.angled").font(.headline)
                    Text("Only the photos you allow will be scanned. Device storage still covers the whole iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Manage selected photos") { showLimitedPicker = true }.disabled(store.busy)
                }
            }
        }
    }
    private var scanCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.scanning ? "Finding room…" : "A fresh start").font(.title3.bold())
                    Spacer()
                    Image(systemName: "sparkle.magnifyingglass").foregroundStyle(.teal)
                }
                Text(store.phase).font(.subheadline).foregroundStyle(.secondary)
                if store.scanning {
                    ProgressView(value: store.progress)
                    Button("Cancel scan", role: .cancel) { store.cancelScan() }
                } else {
                    if let result = store.result {
                        Text("\(result.scanned) photos checked in \(result.seconds, specifier: "%.1f") seconds")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button { store.startScan() } label: {
                        Label(store.result == nil ? "Scan my photos" : "Scan again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).disabled(store.deleting)
                    Text("Keep Clearspace open while scanning. Hidden photos are excluded.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func category(_ title: String, subtitle: String, icon: String, summary: String, color: Color) -> some View {
        Surface {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                    .frame(width: 48, height: 48).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    Text(summary + " to review").font(.subheadline.bold()).foregroundStyle(color)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
        }
    }
}
