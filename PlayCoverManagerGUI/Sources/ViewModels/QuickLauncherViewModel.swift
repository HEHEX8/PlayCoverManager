//
//  QuickLauncherViewModel.swift
//  PlayCoverManagerGUI
//
//  ViewModel for Quick Launcher with real data integration
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
    
    private let shellExecutor = ShellScriptExecutor.shared
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
            // Load real data from shell script
            let installedApps = try await shellExecutor.getInstalledApps()
            
            // Update both local and global state
            apps = installedApps
            appState.apps = installedApps
            
        } catch {
            errorMessage = "アプリリストの読み込みに失敗: \(error.localizedDescription)"
            
            // Fallback to sample data in case of error
            if apps.isEmpty {
                apps = PlayCoverApp.sampleApps
            }
        }
    }
    
    func launchApp(_ app: PlayCoverApp) async {
        selectedApp = app
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Auto-mount if needed
            if app.status == .unmounted {
                try await autoMountVolume(app)
            }
            
            // Handle contaminated internal data
            if app.storageMode == .internalContaminated {
                errorMessage = "内蔵ストレージに意図しないデータが検出されました。\nストレージ切り替えメニューから対処してください。"
                showingLaunchError = true
                return
            }
            
            // Launch the app
            try await shellExecutor.launchApp(bundleId: app.bundleId, appName: app.name)
            
            // Mark as recently launched
            appState.markAsRecentlyLaunched(app.id)
            
            // Refresh app list after a short delay
            try? await Task.sleep(for: .seconds(1))
            await refreshApps()
            
        } catch {
            errorMessage = "アプリの起動に失敗しました: \(error.localizedDescription)"
            showingLaunchError = true
        }
    }
    
    private func autoMountVolume(_ app: PlayCoverApp) async throws {
        // Mount the volume
        let mountPath = AppConstants.playCoverContainer.path
        try await shellExecutor.mountVolume(volumeName: app.volumeName, mountPath: mountPath)
        
        // Wait for mount to complete
        try await Task.sleep(for: .seconds(2))
        
        // Update app status
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].status = .ready
            apps[index].storageMode = .external
        }
    }
    
    func openInFinder(_ app: PlayCoverApp) {
        let url = URL(fileURLWithPath: app.containerPath)
        NSWorkspace.shared.open(url)
    }
    
    func showAppSettings(_ app: PlayCoverApp) {
        // TODO: Show app settings sheet
        selectedApp = app
        print("Show settings for: \(app.name)")
    }
    
    func deleteApp(_ app: PlayCoverApp) async {
        guard let selectedApp = selectedApp else { return }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "アプリを削除"
        alert.informativeText = "\(selectedApp.name) とそのデータをすべて削除しますか？この操作は取り消せません。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        
        let response = alert.runModal()
        
        guard response == .alertFirstButtonReturn else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete app via shell executor
            try await shellExecutor.uninstallApp(appName: selectedApp.name, volumeName: selectedApp.volumeName)
            
            // Remove from local list
            apps.removeAll { $0.id == selectedApp.id }
            appState.apps = apps
            
            self.selectedApp = nil
            
        } catch {
            errorMessage = "アプリの削除に失敗しました: \(error.localizedDescription)"
            showingLaunchError = true
        }
    }
}
