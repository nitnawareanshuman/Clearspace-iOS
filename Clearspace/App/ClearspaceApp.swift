//
//  ClearspaceApp.swift
//  Clearspace
//
//  Created by Anshuman Nitnaware on 27/09/26.
//


import SwiftUI

@main
struct ClearspaceApp: App {
    @StateObject private var store = CleanerStore()
    @StateObject private var contacts = ContactsStore()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash { SplashView { showSplash = false } }
                else { DashboardView() }
            }
                .environmentObject(store)
                .environmentObject(contacts)
                .tint(.teal)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshAccess(); contacts.refreshAccess() }
                    if phase == .background {
                        if store.scanning { store.cancelScan() }
                        contacts.cancelScan()
                    }
                }
        }
    }
}