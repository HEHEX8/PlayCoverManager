//
//  AppState.swift
//  PlayCoverManagerGUI
//
//  Global app state management
//

import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var apps: [PlayCoverApp] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedTab: Tab = .launcher
    @Published var recentlyLaunchedAppId: UUID?
    @Published var showingSetupWizard: Bool = false
    @Published var isCheckingSetup: Bool = true
    
    enum Tab: String, CaseIterable {
        case launcher = "ランチャー"
        case appManagement = "アプリ管理"
        case storageSwitcher = "ストレージ切替"
        case volume = "ボリューム"
        case maintenance = "メンテナンス"
        case logs = "ログ"
        case settings = "設定"
        
        var icon: String {
            switch self {
            case .launcher:
                return "rocket.fill"
            case .appManagement:
                return "shippingbox.fill"
            case .storageSwitcher:
                return "arrow.left.arrow.right.circle.fill"
            case .volume:
                return "externaldrive.fill"
            case .maintenance:
                return "wrench.and.screwdriver.fill"
            case .logs:
                return "doc.text.magnifyingglass"
            case .settings:
                return "gearshape.fill"
            }
        }
    }
    
    private init() {
        // Check if initial setup is needed, then load data
        Task {
            await checkInitialSetup()
            if !showingSetupWizard {
                await loadApps()
            }
        }
    }
    
    func loadApps() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load from shell executor
            let shellExecutor = ShellScriptExecutor.shared
            apps = try await shellExecutor.getInstalledApps()
        } catch {
            // Fallback to sample data on error
            print("Failed to load apps: \(error)")
            
            // Use sample data only if no apps loaded
            if apps.isEmpty {
                apps = PlayCoverApp.sampleApps
            }
        }
    }
    
    func refreshApps() async {
        await loadApps()
    }
    
    func markAsRecentlyLaunched(_ appId: UUID) {
        recentlyLaunchedAppId = appId
        
        // Update app list
        for index in apps.indices {
            apps[index].isRecentlyLaunched = (apps[index].id == appId)
        }
    }
    
    /// Check if initial setup is needed
    func checkInitialSetup() async {
        isCheckingSetup = true
        defer { isCheckingSetup = false }
        
        do {
            // Check if PlayCover APFS volumes exist
            let shellExecutor = ShellScriptExecutor.shared
            let volumes = try await shellExecutor.getVolumes()
            
            // Look for any PlayCover-related volumes
            let hasPlayCoverVolumes = volumes.contains { volume in
                volume.name.contains("PlayCover") || 
                volume.mountPoint.contains("/Users/Shared/PlayCover")
            }
            
            if !hasPlayCoverVolumes {
                // No PlayCover volumes found - show setup wizard
                showingSetupWizard = true
            } else {
                // Volumes exist - skip setup
                showingSetupWizard = false
            }
        } catch {
            print("Failed to check setup status: \(error)")
            // On error, assume setup is needed to be safe
            showingSetupWizard = true
        }
    }
    
    /// Complete setup and load apps
    func completeSetup() async {
        showingSetupWizard = false
        await loadApps()
    }
}
