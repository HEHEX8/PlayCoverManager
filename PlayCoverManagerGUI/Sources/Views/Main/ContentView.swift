//
//  ContentView.swift
//  PlayCoverManagerGUI
//
//  Main content view with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var errorManager = ErrorManager.shared
    
    var body: some View {
        ZStack {
            if appState.isCheckingSetup {
                // Show loading state while checking setup
                setupCheckingView
            } else {
                // Main app content
                mainContent
            }
        }
        .sheet(isPresented: $appState.showingSetupWizard) {
            SetupWizardView()
                .environmentObject(appState)
                .frame(width: 700, height: 500)
                .interactiveDismissDisabled(true)  // Prevent dismissing until setup is complete
        }
        .sheet(isPresented: $errorManager.showingError) {
            if let error = errorManager.currentError {
                ErrorAlertView(
                    error: error,
                    onDismiss: {
                        errorManager.showingError = false
                        errorManager.currentError = nil
                    },
                    onRetry: nil  // TODO: Implement retry logic
                )
            }
        }
    }
    
    @ViewBuilder
    private var setupCheckingView: some View {
        VStack(spacing: 24) {
            // PlayCover logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("PlayCover Manager")
                    .font(.system(size: 32, weight: .bold))
                
                Text("起動準備中...")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    @ViewBuilder
    private var mainContent: some View {
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
                case .storageSwitcher:
                    StorageSwitcherView()
                case .volume:
                    VolumeListView()
                case .maintenance:
                    MaintenanceView()
                case .logs:
                    LogViewerView()
                case .settings:
                    SettingsView()
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
