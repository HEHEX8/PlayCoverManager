//
//  StorageSwitcherViewModel.swift
//  PlayCoverManagerGUI
//
//  ViewModel for storage location switching
//

import Foundation
import SwiftUI

enum TransferDirection {
    case toExternal     // Internal → External
    case toInternal     // External → Internal
}

enum TransferMethod: String {
    case rsync = "rsync"
    case cp = "cp"
    case ditto = "ditto"
    case parallel = "parallel"
}

@MainActor
class StorageSwitcherViewModel: ObservableObject {
    @Published var switchableApps: [PlayCoverApp] = []
    @Published var selectedApp: PlayCoverApp?
    @Published var isLoading = false
    @Published var isTransferring = false
    @Published var transferProgress: Double = 0.0
    @Published var transferSpeed: String?
    @Published var transferETA: String?
    @Published var transferDirection: TransferDirection = .toExternal
    @Published var showingSwitchConfirm = false
    @Published var showingError = false
    @Published var errorMessage: String?
    
    @Published var internalFree = "計算中..."
    @Published var externalFree = "計算中..."
    
    private let shellExecutor = ShellScriptExecutor.shared
    private let appState = AppState.shared
    private let notificationManager = NotificationManager.shared
    private let settings = SettingsViewModel.shared
    
    // Transfer method from settings
    var transferMethod: TransferMethod = .rsync
    
    init() {
        Task {
            await refreshApps()
            await refreshStorageInfo()
        }
    }
    
    func refreshApps() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let allApps = try await shellExecutor.getInstalledApps()
            
            // Filter apps that can be switched
            switchableApps = allApps.filter { app in
                switch app.storageMode {
                case .external, .externalWrongLocation:
                    return true  // Can switch to internal
                case .internalIntentional, .internalContaminated:
                    return true  // Can switch to external
                case .internalIntentionalEmpty, .none:
                    return false // Nothing to switch
                }
            }
            
            appState.apps = allApps
            
        } catch {
            errorMessage = "アプリリストの読み込みに失敗: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func refreshStorageInfo() async {
        do {
            // Get internal storage free space
            let internalPath = FileManager.default.homeDirectoryForCurrentUser.path
            let internalOutput = try await shellExecutor.executeCommand("df -h '\(internalPath)' | tail -1 | awk '{print $4}'")
            internalFree = internalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get external storage free space
            // TODO: Get actual external drive path from settings
            let externalOutput = try await shellExecutor.executeCommand("df -h /Volumes 2>/dev/null | grep -v 'Filesystem' | head -1 | awk '{print $4}'")
            if !externalOutput.isEmpty {
                externalFree = externalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                externalFree = "N/A"
            }
            
        } catch {
            internalFree = "N/A"
            externalFree = "N/A"
        }
    }
    
    func switchStorage() async {
        guard let app = selectedApp else { return }
        
        isTransferring = true
        transferProgress = 0.0
        transferSpeed = nil
        transferETA = nil
        
        // Determine direction
        switch app.storageMode {
        case .external, .externalWrongLocation:
            transferDirection = .toInternal
        case .internalIntentional, .internalContaminated:
            transferDirection = .toExternal
        default:
            return
        }
        
        do {
            if transferDirection == .toExternal {
                try await switchToExternal(app: app)
            } else {
                try await switchToInternal(app: app)
            }
            
            // Success
            await refreshApps()
            
            // Send notification
            notificationManager.notifyStorageSwitchComplete(
                appName: app.name,
                toExternal: transferDirection == .toExternal
            )
            
        } catch {
            errorMessage = "ストレージ切り替えに失敗: \(error.localizedDescription)"
            showingError = true
            
            // Send error notification if enabled
            if settings.notifyOnError {
                notificationManager.notifyError(message: errorMessage ?? "ストレージ切り替えに失敗しました")
            }
        }
        
        isTransferring = false
        selectedApp = nil
    }
    
    private func switchToExternal(app: PlayCoverApp) async throws {
        // Step 1: Check if app is running
        let isRunning = try await shellExecutor.executeCommand("pgrep -f '\(app.name)'")
        if !isRunning.isEmpty {
            throw NSError(domain: "StorageSwitcher", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "アプリが実行中です。終了してから再試行してください。"
            ])
        }
        
        transferProgress = 0.1
        
        // Step 2: Check external volume
        let volumeExists = try await shellExecutor.executeCommand("diskutil list | grep '\(app.volumeName)'")
        if volumeExists.isEmpty {
            // Create volume
            try await createExternalVolume(app: app)
        }
        
        transferProgress = 0.2
        
        // Step 3: Mount volume if needed
        let mountPoint = try? await shellExecutor.executeCommand("diskutil info '\(app.volumeName)' | grep 'Mount Point' | awk -F: '{print $2}' | xargs")
        if mountPoint == nil || mountPoint?.isEmpty == true {
            let targetPath = app.containerPath
            try await shellExecutor.mountVolume(volumeName: app.volumeName, mountPath: targetPath)
        }
        
        transferProgress = 0.3
        
        // Step 4: Transfer data
        let sourcePath = app.containerPath
        let destPath = app.containerPath  // Volume is mounted at container path
        
        try await transferData(from: sourcePath, to: destPath, method: transferMethod)
        
        transferProgress = 1.0
    }
    
    private func switchToInternal(app: PlayCoverApp) async throws {
        // Step 1: Check if app is running
        let isRunning = try await shellExecutor.executeCommand("pgrep -f '\(app.name)'")
        if !isRunning.isEmpty {
            throw NSError(domain: "StorageSwitcher", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "アプリが実行中です。終了してから再試行してください。"
            ])
        }
        
        transferProgress = 0.1
        
        // Step 2: Unmount external volume
        try await shellExecutor.unmountVolume(volumeName: app.volumeName)
        
        transferProgress = 0.2
        
        // Step 3: Transfer data from volume to internal
        let volumePath = "/Volumes/\(app.volumeName)"
        let internalPath = app.containerPath
        
        // Create internal directory
        try await shellExecutor.executeCommand("mkdir -p '\(internalPath)'")
        
        transferProgress = 0.3
        
        // Step 4: Mount volume to temp location for copying
        let tempMount = "/tmp/playcover-temp-\(UUID().uuidString)"
        try await shellExecutor.executeCommand("sudo mkdir -p '\(tempMount)'")
        try await shellExecutor.mountVolume(volumeName: app.volumeName, mountPath: tempMount)
        
        transferProgress = 0.4
        
        // Step 5: Transfer data
        try await transferData(from: tempMount, to: internalPath, method: transferMethod)
        
        transferProgress = 0.9
        
        // Step 6: Unmount temp location
        try await shellExecutor.executeCommand("sudo diskutil unmount '\(tempMount)'")
        try await shellExecutor.executeCommand("sudo rm -rf '\(tempMount)'")
        
        // Step 7: Create internal storage marker
        try await shellExecutor.executeCommand("touch '\(internalPath)/.internal_storage'")
        
        transferProgress = 1.0
    }
    
    private func createExternalVolume(app: PlayCoverApp) async throws {
        // Get external drive identifier
        // TODO: Get from settings
        let externalDrive = "disk2"
        
        // Create APFS volume
        let sizeGB = 100  // Default size
        _ = try await shellExecutor.executeCommand(
            "sudo diskutil apfs addVolume \(externalDrive) APFS '\(app.volumeName)' -size \(sizeGB)g"
        )
    }
    
    private func transferData(from source: String, to destination: String, method: TransferMethod) async throws {
        let command: String
        
        switch method {
        case .rsync:
            command = "rsync -ah --progress '\(source)/' '\(destination)/'"
        case .cp:
            command = "cp -R '\(source)/' '\(destination)/'"
        case .ditto:
            command = "ditto '\(source)' '\(destination)'"
        case .parallel:
            command = "find '\(source)' -type f | xargs -P 4 -I {} cp {} '\(destination)/'"
        }
        
        // Execute transfer with progress monitoring
        // For now, simulate progress
        for i in stride(from: 0.3, through: 0.9, by: 0.1) {
            transferProgress = i
            transferSpeed = "\(Int.random(in: 50...150)) MB/s"
            transferETA = "\(Int.random(in: 10...60)) 秒"
            try await Task.sleep(for: .seconds(1))
        }
        
        // Execute actual command
        _ = try await shellExecutor.executeCommand(command)
    }
}
