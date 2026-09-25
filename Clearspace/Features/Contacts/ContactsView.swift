import SwiftUI
import Contacts

struct ContactsView: View {
    @EnvironmentObject private var store: ContactsStore
    @Environment(\.openURL) private var openURL
    @State private var selected = Set<String>()
    @State private var draft: ContactDraft?
    @State private var selectionNote = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Good people. Fewer copies.").font(.title2.bold())
                        Text("Find cards with a shared full name, phone number or email. Shared details can belong to different people, so nothing is selected automatically.")
                            .foregroundStyle(.secondary)
                        permissionControls
                    }
                }
                if store.scanning {
                    LoadingCompanion(title: "Pip is checking your contacts…")
                    Button("Cancel scan") { store.cancelScan() }.frame(maxWidth: .infinity)
                } else if store.hasAccess {
                    Button { store.startScan() } label: {
                        Label(store.scanned ? "Scan contacts again" : "Scan contacts", systemImage: "person.crop.circle.badge.magnifyingglass")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(.borderedProminent).disabled(store.busy)
                }
                if store.scanned && store.groups.isEmpty {
                    ContentUnavailableView("No duplicate candidates", systemImage: "person.crop.circle.badge.checkmark", description: Text("No shared names, phone numbers or emails were found in the contacts you allow."))
                }
                ForEach(store.groups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(group.records.count) possible duplicates").font(.headline)
                        Text("Keep at least one. Compare details before deleting.").font(.caption).foregroundStyle(.secondary)
                        ForEach(group.records) { record in
                            Surface {
                                VStack(alignment: .leading, spacing: 12) {
                                    ContactDetails(record: record)
                                    Button {
                                        if selected.contains(record.id) { selected.remove(record.id) }
                                        else {
                                            let next = selected.union([record.id])
                                            if ContactPolicy.allows(next, groups: store.groups.map { $0.records.map(\.id) }) { selected = next }
                                            else { selectionNote = true }
                                        }
                                    } label: {
                                        Label(selected.contains(record.id) ? "Selected for deletion" : "Select this contact",
                                            systemImage: selected.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                            .frame(minHeight: 44)
                                    }.accessibilityValue(selected.contains(record.id) ? "Selected" : "Not selected")
                                }
                            }
                        }
                    }
                }
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Duplicate contacts")
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button { draft = store.makeDraft(selected) } label: {
                        Text("Review \(selected.count) contacts").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).padding().background(.regularMaterial).disabled(store.busy)
                }
            }
            .sheet(item: $draft) { ContactReviewView(draft: $0) }
            .onChange(of: store.epoch) { _, _ in selected.removeAll() }
            .alert("Keep one contact", isPresented: $selectionNote) { Button("OK", role: .cancel) {} } message: { Text("Leave at least one contact in each group unselected.") }
            .alert("Contacts", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) { store.message = nil }
            } message: { Text(store.message ?? "") }
    }

    @ViewBuilder private var permissionControls: some View {
        if store.authorization == .notDetermined {
            Text("Contacts access is separate from Photos. Your address book stays on your iPhone.").font(.footnote)
            Button("Choose Contacts access") { Task { await store.requestAccess() } }.buttonStyle(.borderedProminent)
        } else if store.authorization == .restricted {
            Text("Contacts access is restricted by this device's settings. Contact your device administrator.").font(.footnote)
        } else if !store.hasAccess || store.limited {
            Label(store.limited ? "Limited Contacts access" : "Contacts access is off", systemImage: "person.crop.circle.badge.exclamationmark")
            Text(store.limited ? "Only the contacts you share are scanned. Manage the selection in Settings." : "You can still clean photos and videos. To find duplicate contacts, allow access in Settings.").font(.footnote)
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
        } else {
            Label("On-device matching · Nothing auto-selected", systemImage: "lock.shield").font(.caption).foregroundStyle(.teal)
        }
    }
}

struct ContactDetails: View {
    let record: ContactRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(record.name, systemImage: "person.crop.circle.fill").font(.headline)
            if !record.contact.organizationName.isEmpty { Text(record.contact.organizationName).font(.subheadline) }
            if !record.contact.jobTitle.isEmpty { Text(record.contact.jobTitle).font(.caption) }
            ForEach(record.contact.phoneNumbers, id: \.identifier) { phone in
                Text("\(label(phone.label)): \(phone.value.stringValue)").font(.subheadline)
            }
            ForEach(record.contact.emailAddresses, id: \.identifier) { email in
                Text("\(label(email.label)): \(email.value as String)").font(.subheadline)
            }
            ForEach(record.contact.postalAddresses, id: \.identifier) { address in
                Text(CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)).font(.footnote)
            }
            ForEach(record.contact.urlAddresses, id: \.identifier) { url in Text(url.value as String).font(.footnote) }
            if let birthday = record.contact.birthday {
                Text("Birthday: \(birthday.day.map(String.init) ?? "—") / \(birthday.month.map(String.init) ?? "—")\(birthday.year.map { " / \($0)" } ?? "")")
                    .font(.footnote)
            }
        }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func label(_ value: String?) -> String {
        value.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "Other"
    }
}

struct ContactReviewView: View {
    let draft: ContactDraft
    @EnvironmentObject private var store: ContactsStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var error: String?
    private var stale: Bool { draft.epoch != store.epoch || !store.hasAccess }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Surface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Review every contact").font(.title2.bold())
                            Text("Delete \(draft.records.count) contacts; keep \(draft.kept.count) contacts in the affected groups.")
                            Text("Deletion removes the entire card, including notes and fields not shown here. Details are not merged into the kept contacts. Check the Contacts app if you need to compare other fields.")
                            Text("This cannot be undone in Clearspace. Changes may sync to your connected accounts. iOS does not show a second deletion prompt for contacts.")
                                .font(.footnote).foregroundStyle(.red)
                            Text("Storage savings are not reported: iOS does not expose a reliable per-contact size.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if stale { Label("Contacts changed. Cancel and scan again.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    Text("WILL BE DELETED").font(.caption.bold()).foregroundStyle(.red)
                    ForEach(draft.records) { record in Surface { ContactDetails(record: record) } }
                    Text("WILL BE KEPT").font(.caption.bold()).foregroundStyle(.teal)
                    ForEach(draft.kept) { record in Surface { ContactDetails(record: record) } }
                }.padding(20)
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Review contacts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.deleting) } }
                .safeAreaInset(edge: .bottom) {
                    Button(role: .destructive) { confirm = true } label: {
                        HStack {
                            if store.deleting { ProgressView() }
                            Text(store.deleting ? "Deleting contacts…" : "Delete \(draft.records.count) contacts")
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).tint(.red).padding().background(.regularMaterial)
                        .disabled(stale || store.busy)
                }
                .confirmationDialog("Permanently delete these \(draft.records.count) contacts?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Delete reviewed contacts", role: .destructive) {
                        Task {
                            do { try await store.delete(draft); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    Button("Keep everything", role: .cancel) {}
                } message: { Text("Only the cards listed under Will be deleted are removed. This is the final confirmation.") }
                .alert("Contacts could not be deleted", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
                .interactiveDismissDisabled(store.deleting)
        }
    }
}
