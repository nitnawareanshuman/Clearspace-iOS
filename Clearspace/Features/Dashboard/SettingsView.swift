import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var history = CleanupHistory.shared
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    PipMascot()
                        .frame(width: 60, height: 66)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PipSweep")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(AppInformation.version)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Privacy & help") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    HStack {
                        settingsLabel("App permissions", icon: "lock.shield", color: .teal)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                NavigationLink { PrivacyPolicyView() } label: {
                    settingsLabel("Privacy policy", icon: "hand.raised", color: .teal)
                }
                NavigationLink { CleanupHelpView() } label: {
                    settingsLabel("Cleanup guide", icon: "questionmark.circle", color: .indigo)
                }
                if let supportURL = AppInformation.supportURL {
                    Link(destination: supportURL) {
                        HStack {
                            settingsLabel("Contact support", icon: "bubble.left.and.bubble.right", color: .indigo)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                NavigationLink { SpaceFreedView() } label: {
                    settingsLabel("Cleanup history", icon: "clock.arrow.circlepath", color: .teal)
                }
                Button(role: .destructive) { confirmClear = true } label: {
                    settingsLabel("Clear history", icon: "trash", color: history.receipts.isEmpty ? .secondary : .red)
                        .foregroundStyle(history.receipts.isEmpty ? Color.secondary : Color.red)
                }
                .disabled(history.receipts.isEmpty)
            } header: {
                Text("Activity")
            } footer: {
                Text("Clearing history only removes saved cleanup records.")
            }
        }
        .listStyle(.insetGrouped)
        .tint(.teal)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear cleanup history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your photos, contacts and calendar won't change. This cannot be undone.")
        }
    }

    private func settingsLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
    }
}

enum AppInformation {
    // Configure a monitored mailto: address or public HTTPS support page before submission.
    static var supportURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PipSweepSupportURL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "mailto" else { return nil }
        if scheme == "https" && url.host == nil { return nil }
        return url
    }
    static let policyUpdated = "2 October 2026"
    static var version: String {
        let versionNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "2"
        return "Version \(versionNumber) (\(buildNumber))"
    }
    struct PolicySection: Identifiable {
        let title: String
        let detail: String
        var id: String { title }
    }
    static let privacySections = [
        PolicySection(title: "Your content stays with you",
                      detail: "PipSweep analyzes accessible photos, videos, contacts and calendar events on your iPhone. The app does not upload their contents to a developer server, use advertising SDKs, or send app analytics to us. You can use PipSweep without an account."),
        PolicySection(title: "Permissions are your choice",
                      detail: "Photos access is used to find and review media. Contacts access is used only when you choose contact cleanup. Calendar access is used only when you choose calendar cleanup. Limited Photos and Contacts access restricts analysis to shared items. You can change or revoke access in iPhone Settings."),
        PolicySection(title: "What PipSweep saves",
                      detail: "Analysis results and media-size caches are held in memory. Cleanup history saves only dates, item counts and estimated media bytes in the app's local preferences. It does not save copies of photos, contact cards or event contents. You can clear this history in Settings or remove the app to remove its local app data."),
        PolicySection(title: "Removal and your system accounts",
                      detail: "Nothing is removed until you review and approve it. Apple's Photos deletion confirmation is also required for media. Apple or your configured Photos, Contacts and Calendar accounts may sync approved changes across devices. Cloud-only media is not downloaded by PipSweep. Media may remain in Photos' Recently Deleted album before device storage is recovered."),
        PolicySection(title: "Contact and calendar details",
                      detail: "Contact merging cannot read or copy contact notes and does not transfer account-specific fields or group membership. Review these details in Contacts before approving a merge. PipSweep has no undo for contact or calendar changes. The app excludes recurring events, invitations and read-only calendars from calendar cleanup."),
        PolicySection(title: "Support and external pages",
                      detail: "PipSweep is maintained by Anshuman Nitnaware. If you contact support, only the information you choose to send is shared; the app does not automatically attach your media, contacts or events. Your email or web service may process the message under its own policies. Avoid sharing private media, contact details or event contents."),
        PolicySection(title: "Changes to this policy",
                      detail: "This policy describes the current app. Any future feature that sends data off your device will require updated disclosures and, where applicable, permission before that feature is used.")
    ]
}
struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("PipSweep privacy policy").font(.headline)
                Text("Updated \(AppInformation.policyUpdated)").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(AppInformation.privacySections) { section in
                Section(section.title) { Text(section.detail) }
            }
            if let supportURL = AppInformation.supportURL {
                Section {
                    Link("Contact support", destination: supportURL)
                }
            }
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct CleanupHelpView: View {
    var body: some View {
        List {
            Section("A small place to start") {
                Text("After a scan, choose Screenshots, Similar photos, Blurry photos or Large videos. Preview items and select what to remove. Swipe mode includes Keep, Remove and Undo. Your choices only queue items; final review and the system confirmation control deletion.")
            }
            Section("Similar and blurry suggestions") {
                Text("Matching previews and similar shots are suggestions, not proof that files are identical. Blur detection can include intentional soft focus. Inspect each image and decide which version matters to you. At least one copy in each matched group must stay.")
            }
            Section("Recovering photos and videos") {
                Text("Open Photos and find Recently Deleted under Utilities. Authenticate if asked, select the items, and choose Recover. If media has been permanently deleted, PipSweep cannot recover it. Review Recently Deleted in Photos if you want to permanently remove items and reclaim storage.")
            }
            Section("Understanding the space estimate") {
                Text("Estimated media removed measures known resource sizes, not an immediate increase in free device storage. Recently Deleted, iCloud settings, unavailable sizes and other device activity can change the result. Overlapping cleanup categories are counted once in the dashboard total.")
            }
            Section("Merging contacts") {
                Text("Confirm that cards belong to the same person. Check and copy any notes in Contacts before merging. Account-specific fields and group membership are not transferred. Cross-account merges and conflicting single-value details are blocked. PipSweep cannot undo a contact merge or deletion.")
            }
            Section("Calendar cleanup") {
                Text("Only eligible old, writable events are offered. Recurring events, invitations and read-only calendars are skipped. Review every event carefully; PipSweep cannot restore removed calendar events.")
            }
            Section("Missing items or access") {
                Text("Limited access shows only the photos or contacts you shared. Cloud-only media cannot be analyzed locally. Manage access in Settings, return to PipSweep, and scan again. Contacts and Calendar permissions are separate from Photos.")
            }
            if let supportURL = AppInformation.supportURL {
                Section("Get help") {
                    Link("Contact support", destination: supportURL)
                }
            }
        }
        .navigationTitle("Cleanup guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
