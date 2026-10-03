import SwiftUI
import Photos
struct DashboardView: View {
    @EnvironmentObject private var store: CleanerStore
    @EnvironmentObject private var contacts: ContactsStore
    @Environment(\.openURL) private var openURL
    @State private var showLimitedPicker = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PipSweep").font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text("Room for what matters.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PipMascot(animate: !store.scanning).frame(width: 86, height: 92)
                    }
                    storageCard
                    permissionCard
                    if store.hasAccess {
                        scanCard
                        if let result = store.result {
                            Surface {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Potential cleanup", systemImage: "sparkles").font(.headline)
                                    Text(ByteSummary(result.cleanupCandidates).label).font(.title.bold())
                                    Text("Space you may save after reviewing these items.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("YOUR LIBRARY").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                            NavigationLink {
                                PhotoCollectionView(kind: .similar)
                            } label: {
                                category("Similar photos", subtitle: "\(result.groups.count) groups · keep your favorites",
                                    icon: "square.on.square", summary: savings(result.suggestions), color: .teal)
                            }.buttonStyle(.plain)
                            NavigationLink {
                                PhotoCollectionView(kind: .screenshots)
                            } label: {
                                category("Screenshots", subtitle: "\(result.screenshots.count) screenshots to review",
                                    icon: "viewfinder", summary: savings(result.screenshotCandidates), color: .indigo)
                            }.buttonStyle(.plain)
                            NavigationLink {
                                PhotoCollectionView(kind: .blurry)
                            } label: {
                                category("Blurry photos", subtitle: "\(result.blurryPhotos.count) possible blurry shots to review",
                                    icon: "camera.metering.center.weighted", summary: savings(result.blurryCandidates), color: .orange)
                            }.buttonStyle(.plain)
                            NavigationLink { VideoCollectionView() } label: {
                                category("Large videos", subtitle: "\(result.videos.count) videos · largest first",
                                    icon: "play.rectangle.fill", summary: savings(result.videoCandidates), color: .purple)
                            }.buttonStyle(.plain)
                            Surface {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("About storage savings", systemImage: "info.circle").font(.subheadline.bold())
                                    Text("Savings are approximate. Items may appear in more than one category, but the total counts each item once. Space may not be freed until items leave Recently Deleted in Photos.")
                                    if result.unavailable > 0 || result.blurUnassessed > 0 || result.unmeasured > 0 {
                                        DisclosureGroup("Scan details") {
                                            VStack(alignment: .leading, spacing: 8) {
                                                if result.unavailable > 0 {
                                                    Text("\(result.unavailable) photos couldn't be checked on this device.")
                                                }
                                                if result.blurUnassessed > 0 {
                                                    Text("\(result.blurUnassessed) photos couldn't be checked for blur.")
                                                }
                                                if result.unmeasured > 0 {
                                                    Text("\(result.unmeasured) items have unknown sizes and aren't included in the estimate.")
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 6)
                                        }
                                        .tint(.teal)
                                    }
                                }.font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink { ContactsView() } label: {
                        category("Duplicate contacts", subtitle: contacts.scanned ? "\(contacts.groups.count) groups to compare" : "Find repeated names, numbers and emails",
                            icon: "person.crop.rectangle.stack", summary: contacts.scanned ? "Up to \(contacts.duplicateCount) extra cards" : "Scan separately", color: .orange)
                    }.buttonStyle(.plain)
                    Text("Contact sizes are unavailable. Review duplicates to tidy your address book.")
                        .font(.caption).foregroundStyle(.secondary)
                    NavigationLink { CalendarCleanupView() } label: {
                        category("Calendar cleanup", subtitle: "Review old events before removing them",
                            icon: "calendar.badge.minus", summary: "Tidy your calendar", color: .pink)
                    }.buttonStyle(.plain)
                    NavigationLink { SpaceFreedView() } label: {
                        category("Space freed", subtitle: "Your completed cleanup activity",
                            icon: "sparkles", summary: "View summary", color: .teal)
                    }.buttonStyle(.plain)
                    Surface {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Storage on your Home Screen", systemImage: "square.grid.2x2").font(.headline)
                            Text("Touch and hold your Home Screen, choose Edit → Add Widget, then search for PipSweep. Choose the small or medium storage widget.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Label("Private by design. Processed on your device.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(20)
            }.disabled(store.scanning)
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { SettingsView() } label: {
                            Image(systemName: "gearshape").accessibilityLabel("Settings, privacy and help")
                        }
                    }
                }
                .overlay {
                    if store.scanning {
                        MascotWaitingPopup(phase: store.phase, progress: store.progress) {
                            store.cancelScan()
                        }
                    }
                }
                .sheet(isPresented: $showLimitedPicker, onDismiss: { store.refreshLimitedSelection() }) {
                    NavigationStack {
                        LimitedLibraryPicker().navigationTitle("Photos access")
                            .toolbar { ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showLimitedPicker = false }
                            } }
                    }
                }
                .alert("PipSweep", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("OK", role: .cancel) { store.message = nil }
                } message: { Text(store.message ?? "") }
        }
    }
    private func savings(_ items: [PhotoItem]) -> String {
        let summary = ByteSummary(items)
        if summary.unknown > 0 { return "Potential savings: \(summary.label)" }
        return "Up to \(summary.label) to free"
    }
    private var storageCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 18) {
                #if targetEnvironment(simulator)
                Text("SIMULATOR · MAC STORAGE").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.teal)
                #else
                Text("YOUR DEVICE").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.teal)
                #endif
                if let storage = store.storage {
                    Text(ByteCountFormatter.string(fromByteCount: storage.free, countStyle: .file))
                        .font(.system(size: 44, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("free for your next favorite moment").foregroundStyle(.secondary)
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
                    Text("Allow Photos access to find similar shots, blurry photos, screenshots and large videos. Everything is analyzed on this iPhone. You review each selection before iOS asks you to confirm deletion.")
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
                    Text("Only the photos and videos you allow will be scanned. Device storage still covers the whole iPhone.")
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
                    Text(store.scanning ? "Pip is finding room…" : "Let’s make some room").font(.title3.bold())
                    Spacer()
                    if store.scanning { PipMascot(working: true, animate: false).frame(width: 60, height: 64) }
                    else { PipMascot(animate: !store.scanning).frame(width: 60, height: 64) }
                }
                Text(store.phase).font(.subheadline).foregroundStyle(.secondary)
                if store.scanning {
                    ProgressView(value: store.progress)
                    Button("Cancel scan", role: .cancel) { store.cancelScan() }
                } else {
                    if let result = store.result {
                        Text("\(result.scanned) media items checked in \(result.seconds, specifier: "%.1f") seconds")
                            .font(.caption).foregroundStyle(.secondary)
                        if result.unavailable > 0 {
                            Label("\(result.unavailable) photos could not be loaded or analyzed. Results may be incomplete.", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if result.similarityUnavailable > 0 {
                            Label("Some similar-photo analysis failed. Exact-image matching remains available; near matches may be missing.", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Button { store.startScan() } label: {
                        Label(store.result == nil ? "Scan photos & videos" : "Scan again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).disabled(store.deleting)
                    Text("Keep PipSweep open while scanning. Hidden photos are excluded.").font(.caption).foregroundStyle(.secondary)
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
                    Text(summary).font(.subheadline.bold()).foregroundStyle(color)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
        }
    }
}
