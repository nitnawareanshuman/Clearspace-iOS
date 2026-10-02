import SwiftUI
import EventKit

struct CalendarCleanupView: View {
    @StateObject private var store = CalendarStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var selected = Set<String>()
    @State private var confirmTestData = false
    @State private var review: CalendarReview?
    private var chosen: [CalendarItem] { store.items.filter { selected.contains($0.id) } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Make room in your calendar", systemImage: "calendar.badge.minus").font(.headline)
                        Text("Review events from the past year that ended more than 30 days ago. Recurring events, invitations and read-only calendars are excluded.")
                        Text("Event sizes are unavailable. This tidies your calendar; it does not promise a measurable storage saving.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !store.hasAccess {
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Allow full Calendar access to find old events. You choose and confirm every event before removal.")
                            if store.authorization == .notDetermined || store.authorization == .writeOnly {
                                Button("Allow Calendar access") { Task { await store.requestAccess() } }
                                    .buttonStyle(.borderedProminent)
                            } else if store.authorization == .restricted {
                                Text("Calendar access is restricted by this device’s settings.")
                            } else {
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                } else {
                    Button(store.scanned ? "Scan again" : "Scan old events") { Task { await store.scan() } }
                        .buttonStyle(.borderedProminent).disabled(store.busy)
                    #if DEBUG
                    Button("Add test calendar events") { confirmTestData = true }
                        .font(.footnote).disabled(store.busy)
                        .confirmationDialog("Create a disposable test calendar?", isPresented: $confirmTestData, titleVisibility: .visible) {
                            Button("Create five test events") { Task { await store.addTestEvents() } }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("Adds two old, one recent, one future and one repeating event to a new PipSweep Test calendar. It may sync through your calendar account. Tap Scan old events after creation. Available in Debug builds only.")
                        }
                    #endif
                    if store.scanning { ProgressView("Checking your calendars…") }
                    if store.scanned && store.items.isEmpty {
                        PipMascot().frame(width: 120, height: 130).frame(maxWidth: .infinity)
                        Text("No eligible old events. Recent, recurring, invited and read-only events are kept.")
                            .foregroundStyle(.secondary)
                    }
                    if !store.items.isEmpty {
                        Button(selected.count == store.items.count ? "Deselect all" : "Select all listed events") {
                            selected = selected.count == store.items.count ? [] : Set(store.items.map(\.id))
                        }
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(store.items) { item in
                            Button {
                                if selected.contains(item.id) { selected.remove(item.id) }
                                else { selected.insert(item.id) }
                            } label: {
                                Surface {
                                    HStack(spacing: 12) {
                                        Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(.teal)
                                        CalendarEventLabel(item: item)
                                    }
                                }
                            }.buttonStyle(.plain)
                                .accessibilityValue(selected.contains(item.id) ? "Selected" : "Not selected")
                        }
                    }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Calendar cleanup").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button("Review \(chosen.count) events") {
                        review = CalendarReview(revision: store.revision, items: chosen)
                    }.buttonStyle(.borderedProminent).disabled(store.busy || chosen.isEmpty)
                        .padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
            }
            .onChange(of: store.revision) { _, _ in selected.removeAll() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshAccess() } }
            .sheet(item: $review) { CalendarReviewView(review: $0, store: store) }
            .alert("Calendar cleanup", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
    }
}

struct CalendarReview: Identifiable {
    let id = UUID()
    let revision: Int
    let items: [CalendarItem]
}

private struct CalendarEventLabel: View {
    let item: CalendarItem
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).font(.headline)
            Text(item.calendarTitle).font(.subheadline).foregroundStyle(.secondary)
            Text(item.start.formatted(date: .abbreviated, time: item.allDay ? .omitted : .shortened))
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarReviewView: View {
    let review: CalendarReview
    @ObservedObject var store: CalendarStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var error: String?
    @State private var receipt: CleanupReceipt?
    private var stale: Bool { review.revision != store.revision || !store.hasAccess }
    var body: some View {
        NavigationStack {
            Group {
                if let receipt {
                    SpaceFreedView(receipt: receipt, done: { dismiss() })
                } else {
                    List {
                        Section {
                            Text("Only these \(review.items.count) events will be removed. Calendar deletion may sync to your other devices. There is no Recently Deleted recovery provided by this app.")
                            Text("Storage saving: unavailable").foregroundStyle(.secondary)
                            if stale { Text("Calendar changed. Cancel and scan again.").foregroundStyle(.orange) }
                        }
                        Section("Events to remove") {
                            ForEach(review.items) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    CalendarEventLabel(item: item)
                                    Text("Ends: \(item.end.formatted(date: .abbreviated, time: item.allDay ? .omitted : .shortened))").font(.caption)
                                    if let location = item.location, !location.isEmpty { Text(location).font(.footnote) }
                                    if let notes = item.notes, !notes.isEmpty { Text(notes).font(.footnote) }
                                }
                            }
                        }
                    }.navigationTitle("Review events").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }.disabled(store.deleting)
                        } }
                        .safeAreaInset(edge: .bottom) {
                            Button("Delete \(review.items.count) events", role: .destructive) { confirm = true }
                                .buttonStyle(.borderedProminent).tint(.red).disabled(stale || store.busy)
                                .padding().frame(maxWidth: .infinity).background(.regularMaterial)
                        }
                }
            }
            .confirmationDialog("Permanently remove these reviewed events?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Delete reviewed events", role: .destructive) {
                    Task {
                        do { receipt = try await store.delete(review.items, revision: review.revision) }
                        catch { self.error = error.localizedDescription }
                    }
                }
                Button("Keep events", role: .cancel) { }
            } message: { Text("This also affects calendars synced to other devices.") }
            .alert("Calendar not confirmed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .overlay {
                if store.deleting { MascotWaitingView(title: "Pip is tidying up…", detail: "Removing your approved calendar events.") }
            }
            .interactiveDismissDisabled(store.deleting)
        }
    }
}
