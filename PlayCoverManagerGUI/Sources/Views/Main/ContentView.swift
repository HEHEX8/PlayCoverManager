//
//  ContentView.swift
//  PlayCoverManagerGUI
//
//  Main content view with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            // Detail view based on selected tab
            Group {
                switch appState.selectedTab {
                case .launcher:
                    QuickLauncherView()
                case .appManagement:
                    AppManagementView()
                case .volume:
                    VolumeListView()
                case .settings:
                    SettingsView()
                case .maintenance:
                    MaintenanceView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .frame(width: 900, height: 600)
}
