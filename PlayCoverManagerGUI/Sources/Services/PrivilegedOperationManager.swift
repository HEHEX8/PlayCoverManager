//
//  PrivilegedOperationManager.swift
//  PlayCoverManagerGUI
//
//  Manager for operations requiring elevated privileges (sudo)
//

import Foundation
import AppKit
import Security

@MainActor
class PrivilegedOperationManager {
    static let shared = PrivilegedOperationManager()
    
    private var authorizationRef: AuthorizationRef?
    private let logger = Logger.shared
    
    private init() {}
    
    /// Request authorization for privileged operations
    func requestAuthorization() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var authRef: AuthorizationRef?
                let status = AuthorizationCreate(nil, nil, [], &authRef)
                
                DispatchQueue.main.async {
                    if status == errAuthorizationSuccess {
                        self.authorizationRef = authRef
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: PrivilegedOperationError.authorizationFailed(status: status))
                    }
                }
            }
        }
    }
    
    /// Execute a command with sudo privileges
    func executeSudoCommand(_ command: String, arguments: [String] = []) async throws -> String {
        // Ensure we have authorization
        if authorizationRef == nil {
            try await requestAuthorization()
        }
        
        guard let authRef = authorizationRef else {
            throw PrivilegedOperationError.noAuthorization
        }
        
        logger.debug(.system, "Executing sudo command: \(command) \(arguments.joined(separator: " "))")
        
        // For now, use osascript to prompt for password
        // This is simpler than SMJobBless and works for our use case
        let script = """
        do shell script "\(command) \(arguments.joined(separator: " "))" with administrator privileges
        """
        
        return try await executeAppleScript(script)
    }
    
    /// Execute an AppleScript with administrator privileges
    private func executeAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                
                guard let scriptObject = NSAppleScript(source: script) else {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: PrivilegedOperationError.scriptCreationFailed)
                    }
                    return
                }
                
                let output = scriptObject.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if let error = error {
                        let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                        continuation.resume(throwing: PrivilegedOperationError.executionFailed(message: errorMessage))
                    } else {
                        continuation.resume(returning: output.stringValue ?? "")
                    }
                }
            }
        }
    }
    
    // MARK: - Disk Operations
    
    /// Create an APFS volume with sudo privileges
    func createAPFSVolume(
        containerDisk: String,
        volumeName: String,
        size: String
    ) async throws {
        let command = "diskutil"
        let args = [
            "apfs", "addVolume",
            containerDisk,
            "APFS",
            volumeName,
            "-size", size
        ]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.volume, "Created APFS volume: \(volumeName) on \(containerDisk)")
    }
    
    /// Mount a volume to a specific path
    func mountVolume(volumeName: String, mountPath: String) async throws {
        // Create mount point if needed
        let mkdirCommand = "mkdir"
        let mkdirArgs = ["-p", mountPath]
        _ = try await executeSudoCommand(mkdirCommand, arguments: mkdirArgs)
        
        // Mount the volume
        let command = "diskutil"
        let args = [
            "mount",
            "-mountPoint", mountPath,
            volumeName
        ]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.volume, "Mounted volume: \(volumeName) at \(mountPath)")
    }
    
    /// Unmount a volume
    func unmountVolume(volumeName: String) async throws {
        let command = "diskutil"
        let args = ["unmount", volumeName]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.volume, "Unmounted volume: \(volumeName)")
    }
    
    /// Eject a volume
    func ejectVolume(volumeName: String) async throws {
        let command = "diskutil"
        let args = ["eject", volumeName]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.volume, "Ejected volume: \(volumeName)")
    }
    
    /// Delete an APFS volume
    func deleteAPFSVolume(volumeName: String) async throws {
        let command = "diskutil"
        let args = ["apfs", "deleteVolume", volumeName]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.volume, "Deleted APFS volume: \(volumeName)")
    }
    
    // MARK: - File Operations
    
    /// Copy files with sudo privileges
    func sudoCopy(from source: String, to destination: String) async throws {
        let command = "cp"
        let args = ["-R", source, destination]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.transfer, "Copied \(source) to \(destination)")
    }
    
    /// Move files with sudo privileges
    func sudoMove(from source: String, to destination: String) async throws {
        let command = "mv"
        let args = [source, destination]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.transfer, "Moved \(source) to \(destination)")
    }
    
    /// Remove files with sudo privileges
    func sudoRemove(path: String) async throws {
        let command = "rm"
        let args = ["-rf", path]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.system, "Removed \(path)")
    }
    
    /// Change ownership of files
    func changeOwnership(path: String, owner: String, group: String) async throws {
        let command = "chown"
        let args = ["-R", "\(owner):\(group)", path]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.system, "Changed ownership of \(path) to \(owner):\(group)")
    }
    
    /// Change permissions of files
    func changePermissions(path: String, mode: String) async throws {
        let command = "chmod"
        let args = ["-R", mode, path]
        
        _ = try await executeSudoCommand(command, arguments: args)
        logger.info(.system, "Changed permissions of \(path) to \(mode)")
    }
    
    // MARK: - Cache Operations
    
    /// Clear system caches (requires sudo)
    func clearSystemCaches() async throws {
        // Clear user cache
        let userCache = NSHomeDirectory() + "/Library/Caches"
        _ = try await executeSudoCommand("rm", arguments: ["-rf", "\(userCache)/*"])
        
        // Clear system cache (requires sudo)
        _ = try await executeSudoCommand("rm", arguments: ["-rf", "/Library/Caches/*"])
        
        logger.info(.system, "Cleared system caches")
    }
    
    /// Delete APFS snapshots (requires sudo)
    func deleteAPFSSnapshots(volume: String) async throws {
        // List snapshots
        let listCommand = "tmutil"
        let listArgs = ["listlocalsnapshots", volume]
        let output = try await executeSudoCommand(listCommand, arguments: listArgs)
        
        // Parse and delete each snapshot
        let snapshots = output.components(separatedBy: "\n")
            .filter { $0.contains("com.apple.TimeMachine") }
        
        for snapshot in snapshots {
            let snapshotName = snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            let deleteCommand = "tmutil"
            let deleteArgs = ["deletelocalsnapshots", snapshotName]
            _ = try await executeSudoCommand(deleteCommand, arguments: deleteArgs)
        }
        
        logger.info(.maintenance, "Deleted \(snapshots.count) APFS snapshots")
    }
    
    // MARK: - Helper Methods
    
    /// Check if we have valid authorization
    var hasAuthorization: Bool {
        return authorizationRef != nil
    }
    
    /// Release authorization
    func releaseAuthorization() {
        if let authRef = authorizationRef {
            AuthorizationFree(authRef, [])
            authorizationRef = nil
        }
    }
    
    deinit {
        releaseAuthorization()
    }
}

// MARK: - Errors

enum PrivilegedOperationError: LocalizedError {
    case authorizationFailed(status: OSStatus)
    case noAuthorization
    case scriptCreationFailed
    case executionFailed(message: String)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let status):
            return "認証に失敗しました (Status: \(status))"
        case .noAuthorization:
            return "認証されていません"
        case .scriptCreationFailed:
            return "スクリプトの作成に失敗しました"
        case .executionFailed(let message):
            return "実行に失敗しました: \(message)"
        case .userCancelled:
            return "ユーザーによってキャンセルされました"
        }
    }
}
