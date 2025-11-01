//
//  QuickLauncherViewModel.swift
//  PlayCoverManagerGUI
//
//  ViewModel for Quick Launcher
//

import Foundation
import SwiftUI

@MainActor
class QuickLauncherViewModel: ObservableObject {
    @Published var apps: [PlayCoverApp] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingLaunchError: Bool = false
    @Published var selectedApp: PlayCoverApp?
    
    private let shellExecutor = ShellScriptExecutor()
    private let appState = AppState.shared
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        // Get apps from AppState
        apps = appState.apps
    }
    
    func refreshApps() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Call shell script to get latest app list
            try await Task.sleep(for: .seconds(0.5))
            
            // For now, reload from AppState
            await appState.refreshApps()
            loadApps()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func launchApp(_ app: PlayCoverApp) async {
        selectedApp = app
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if needs mounting first
            if app.status == .unmounted {
                try await mountVolume(app)
            }
            
            // Launch the app
            try await shellExecutor.launchApp(bundleId: app.bundleId)
            
            // Mark as recently launched
            appState.markAsRecentlyLaunched(app.id)
            
            // Refresh app list
            await refreshApps()
            
        } catch {
            errorMessage = "アプリの起動に失敗しました: \(error.localizedDescription)"
            showingLaunchError = true
        }
    }
    
    func mountVolume(_ app: PlayCoverApp) async throws {
        try await shellExecutor.mountVolume(volumeName: app.volumeName)
        
        // Wait a bit for mount to complete
        try await Task.sleep(for: .seconds(1))
    }
    
    func openInFinder(_ app: PlayCoverApp) {
        let url = URL(fileURLWithPath: app.containerPath)
        NSWorkspace.shared.open(url)
    }
    
    func showAppSettings(_ app: PlayCoverApp) {
        // TODO: Implement app settings
        selectedApp = app
    }
    
    func deleteApp(_ app: PlayCoverApp) async {
        // TODO: Implement app deletion with confirmation
    }
}
