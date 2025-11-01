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
    
    enum Tab: String, CaseIterable {
        case launcher = "ランチャー"
        case appManagement = "アプリ管理"
        case volume = "ボリューム"
        case settings = "設定"
        case maintenance = "メンテナンス"
        
        var icon: String {
            switch self {
            case .launcher:
                return "rocket.fill"
            case .appManagement:
                return "shippingbox.fill"
            case .volume:
                return "externaldrive.fill"
            case .settings:
                return "gearshape.fill"
            case .maintenance:
                return "wrench.and.screwdriver.fill"
            }
        }
    }
    
    private init() {
        // Load initial data asynchronously
        Task {
            await loadApps()
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
}
