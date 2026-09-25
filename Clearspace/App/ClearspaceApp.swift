import SwiftUI

@main
struct ClearspaceApp: App {
    @StateObject private var store = CleanerStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
                .tint(.teal)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshAccess() }
                    if phase == .background && store.scanning { store.cancelScan() }
                }
        }
    }
}
