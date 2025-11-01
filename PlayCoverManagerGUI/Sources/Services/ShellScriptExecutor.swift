//
//  ShellScriptExecutor.swift
//  PlayCoverManagerGUI
//
//  Execute Zsh shell scripts from Swift
//

import Foundation

enum ShellError: Error, LocalizedError {
    case scriptNotFound(String)
    case executionFailed(Int32, String)
    case invalidOutput(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "スクリプトが見つかりません: \(path)"
        case .executionFailed(let code, let message):
            return "実行エラー (コード: \(code)): \(message)"
        case .invalidOutput(let message):
            return "出力の解析エラー: \(message)"
        case .parseError(let message):
            return "パースエラー: \(message)"
        }
    }
}

@MainActor
class ShellScriptExecutor: ObservableObject {
    static let shared = ShellScriptExecutor()
    
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    
    private let scriptsDirectory: URL
    
    init() {
        // Get the bundle's Resources/Scripts directory
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Scripts") {
            self.scriptsDirectory = bundleURL
        } else {
            // Fallback to current directory (for development)
            self.scriptsDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/Resources/Scripts")
        }
    }
    
    // MARK: - Script Execution
    
    /// Execute a shell script with arguments
    func execute(
        script: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> String {
        isRunning = true
        defer { isRunning = false }
        
        let scriptURL = scriptsDirectory.appendingPathComponent(script)
        
        // Check if script exists
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw ShellError.scriptNotFound(scriptURL.path)
        }
        
        return try await executeProcess(
            executable: "/bin/zsh",
            arguments: [scriptURL.path] + arguments,
            environment: environment
        )
    }
    
    /// Execute a shell command directly
    func executeCommand(
        _ command: String,
        environment: [String: String]? = nil
    ) async throws -> String {
        isRunning = true
        defer { isRunning = false }
        
        return try await executeProcess(
            executable: "/bin/zsh",
            arguments: ["-c", command],
            environment: environment
        )
    }
    
    // MARK: - Private Methods
    
    private func executeProcess(
        executable: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        // Set environment variables
        var env = ProcessInfo.processInfo.environment
        if let environment = environment {
            for (key, value) in environment {
                env[key] = value
            }
        }
        process.environment = env
        
        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Start process
        try process.run()
        
        // Read output asynchronously
        let outputData = try await outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try await errorPipe.fileHandleForReading.readToEnd() ?? Data()
        
        // Wait for process to complete
        process.waitUntilExit()
        
        let exitCode = process.terminationStatus
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        self.output = output
        
        // Check exit code
        if exitCode != 0 {
            throw ShellError.executionFailed(exitCode, errorOutput)
        }
        
        return output
    }
}

// MARK: - FileHandle Extension for async/await
extension FileHandle {
    func readToEnd() async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.readToEnd()
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - App Management
extension ShellScriptExecutor {
    /// Get list of installed PlayCover apps
    func getInstalledApps() async throws -> [PlayCoverApp] {
        // Read mapping file directly
        let mappingFileURL = AppConstants.mappingFile
        
        guard FileManager.default.fileExists(atPath: mappingFileURL.path) else {
            // No apps installed yet
            return []
        }
        
        let content = try String(contentsOf: mappingFileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var apps: [PlayCoverApp] = []
        
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            let appName = parts[0]
            let volumeName = parts[1]
            
            // Generate bundle ID (simplified)
            let bundleId = "com.playcover.\(appName.replacingOccurrences(of: " ", with: "").lowercased())"
            let containerPath = AppConstants.playCoverContainer.appendingPathComponent("Data/\(bundleId)").path
            
            // Detect storage mode and status
            let (storageMode, status) = try await detectStorageMode(
                volumeName: volumeName,
                containerPath: containerPath
            )
            
            // Get size
            let size = await getContainerSize(containerPath)
            
            // Check if recently launched
            let isRecent = await isRecentlyLaunched(appName)
            
            let app = PlayCoverApp(
                name: appName,
                bundleId: bundleId,
                volumeName: volumeName,
                containerPath: containerPath,
                storageMode: storageMode,
                status: status,
                size: size,
                requiresSudo: true, // Assume all need sudo for now
                isRecentlyLaunched: isRecent
            )
            
            apps.append(app)
        }
        
        return apps
    }
    
    /// Detect storage mode and status for an app
    private func detectStorageMode(volumeName: String, containerPath: String) async throws -> (StorageMode, AppStatus) {
        // Check if volume exists
        let volumeExists = try await checkVolumeExists(volumeName)
        
        if !volumeExists {
            return (.none, .empty)
        }
        
        // Check if volume is mounted
        let mountPoint = try await getVolumeMountPoint(volumeName)
        
        if let mountPoint = mountPoint {
            // Volume is mounted
            let expectedPath = AppConstants.playCoverContainer.path
            
            if mountPoint == expectedPath {
                // Correctly mounted
                return (.external, .ready)
            } else {
                // Mounted at wrong location
                return (.externalWrongLocation, .needsRemount)
            }
        } else {
            // Volume is not mounted
            
            // Check for internal data
            if FileManager.default.fileExists(atPath: containerPath) {
                // Has internal data
                let markerPath = "\(containerPath)/.internal_storage"
                
                if FileManager.default.fileExists(atPath: markerPath) {
                    // Intentional internal storage
                    return (.internalIntentional, .ready)
                } else {
                    // Contaminated (unintended internal data)
                    return (.internalContaminated, .warning)
                }
            } else {
                // No data, just unmounted
                return (.external, .unmounted)
            }
        }
    }
    
    /// Check if volume exists
    private func checkVolumeExists(_ volumeName: String) async throws -> Bool {
        let output = try await executeCommand("diskutil list | grep '\(volumeName)'")
        return !output.isEmpty
    }
    
    /// Get volume mount point
    private func getVolumeMountPoint(_ volumeName: String) async throws -> String? {
        do {
            let output = try await executeCommand("diskutil info '\(volumeName)' | grep 'Mount Point' | awk -F: '{print $2}' | xargs")
            return output.isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    /// Get container size
    private func getContainerSize(_ path: String) async -> String {
        do {
            let output = try await executeCommand("du -sh '\(path)' 2>/dev/null | awk '{print $1}'")
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "0 B"
        }
    }
    
    /// Check if app was recently launched
    private func isRecentlyLaunched(_ appName: String) async -> Bool {
        let recentFile = AppConstants.recentAppFile
        
        guard FileManager.default.fileExists(atPath: recentFile.path) else {
            return false
        }
        
        do {
            let content = try String(contentsOf: recentFile, encoding: .utf8)
            return content.trimmingCharacters(in: .whitespacesAndNewlines) == appName
        } catch {
            return false
        }
    }
}

// MARK: - App Operations
extension ShellScriptExecutor {
    /// Launch an app
    func launchApp(bundleId: String, appName: String) async throws {
        // Update recent app file
        try? appName.write(to: AppConstants.recentAppFile, atomically: true, encoding: .utf8)
        
        // Launch via open command
        let appsDir = AppConstants.playCoverAppsDir.path
        let appPath = "\(appsDir)/\(appName).app"
        
        if FileManager.default.fileExists(atPath: appPath) {
            _ = try await executeCommand("open '\(appPath)'")
        } else {
            // Try with bundle ID
            _ = try await executeCommand("open -b '\(bundleId)'")
        }
    }
    
    /// Install IPA file
    func installIPA(ipaPath: String) async throws {
        // Use PlayCover's built-in install
        let playCoverApp = "/Applications/PlayCover.app"
        _ = try await executeCommand("open -a '\(playCoverApp)' '\(ipaPath)'")
    }
    
    /// Uninstall app
    func uninstallApp(appName: String, volumeName: String) async throws {
        // Delete app
        let appPath = "\(AppConstants.playCoverAppsDir.path)/\(appName).app"
        _ = try await executeCommand("rm -rf '\(appPath)'")
        
        // Delete volume
        _ = try await executeCommand("diskutil apfs deleteVolume '\(volumeName)'")
        
        // Remove from mapping file
        await removeMappingEntry(appName: appName)
    }
    
    private func removeMappingEntry(appName: String) async {
        do {
            let mappingFileURL = AppConstants.mappingFile
            var content = try String(contentsOf: mappingFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let filteredLines = lines.filter { !$0.hasPrefix(appName + "\t") }
            content = filteredLines.joined(separator: "\n")
            try content.write(to: mappingFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to remove mapping entry: \(error)")
        }
    }
}

// MARK: - Volume Operations
extension ShellScriptExecutor {
    /// Get list of volumes
    func getVolumes() async throws -> [VolumeInfo] {
        let mappingFileURL = AppConstants.mappingFile
        
        guard FileManager.default.fileExists(atPath: mappingFileURL.path) else {
            return []
        }
        
        let content = try String(contentsOf: mappingFileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var volumes: [VolumeInfo] = []
        
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            let appName = parts[0]
            let volumeName = parts[1]
            
            // Get mount point
            let mountPoint = try? await getVolumeMountPoint(volumeName)
            let isMounted = mountPoint != nil
            
            // Get size info
            let (total, used) = await getVolumeSize(volumeName)
            
            let volume = VolumeInfo(
                name: volumeName,
                app: appName,
                isMounted: isMounted,
                totalSpace: total,
                usedSpace: used,
                mountPath: mountPoint
            )
            
            volumes.append(volume)
        }
        
        return volumes
    }
    
    /// Get volume size
    private func getVolumeSize(_ volumeName: String) async -> (String, String) {
        do {
            let output = try await executeCommand("diskutil info '\(volumeName)' | grep 'Volume Total Space\\|Volume Used Space'")
            let lines = output.components(separatedBy: .newlines)
            
            var total = "0 GB"
            var used = "0 GB"
            
            for line in lines {
                if line.contains("Volume Total Space") {
                    if let match = line.components(separatedBy: ":").last {
                        total = match.trimmingCharacters(in: .whitespaces)
                    }
                } else if line.contains("Volume Used Space") {
                    if let match = line.components(separatedBy: ":").last {
                        used = match.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            return (total, used)
        } catch {
            return ("0 GB", "0 GB")
        }
    }
    
    /// Mount a volume
    func mountVolume(volumeName: String, mountPath: String) async throws {
        // Create mount point
        _ = try? await executeCommand("sudo mkdir -p '\(mountPath)'")
        
        // Mount volume
        _ = try await executeCommand("sudo diskutil mount -mountPoint '\(mountPath)' '\(volumeName)'")
    }
    
    /// Unmount a volume
    func unmountVolume(volumeName: String) async throws {
        _ = try await executeCommand("sudo diskutil unmount '\(volumeName)'")
    }
    
    /// Remount a volume
    func remountVolume(volumeName: String, mountPath: String) async throws {
        try await unmountVolume(volumeName: volumeName)
        try await Task.sleep(for: .milliseconds(500))
        try await mountVolume(volumeName: volumeName, mountPath: mountPath)
    }
    
    /// Mount all volumes
    func mountAllVolumes() async throws {
        let volumes = try await getVolumes()
        
        for volume in volumes where !volume.isMounted {
            let mountPath = AppConstants.playCoverContainer.path
            try? await mountVolume(volumeName: volume.name, mountPath: mountPath)
        }
    }
    
    /// Unmount all volumes
    func unmountAllVolumes() async throws {
        let volumes = try await getVolumes()
        
        for volume in volumes where volume.isMounted {
            try? await unmountVolume(volumeName: volume.name)
        }
    }
}

// MARK: - Maintenance Operations
extension ShellScriptExecutor {
    /// Get APFS snapshots
    func getAPFSSnapshots() async throws -> [String] {
        let output = try await executeCommand("tmutil listlocalsnapshots / | grep 'com.apple'")
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    /// Delete APFS snapshots
    func deleteAPFSSnapshots() async throws {
        let snapshots = try await getAPFSSnapshots()
        
        for snapshot in snapshots {
            _ = try? await executeCommand("sudo tmutil deletelocalsnapshots \(snapshot)")
        }
    }
    
    /// Clear system cache
    func clearSystemCache() async throws {
        let cachePaths = [
            "~/Library/Caches/*",
            "/tmp/*",
            "~/Library/Updates/*"
        ]
        
        for path in cachePaths {
            _ = try? await executeCommand("rm -rf \(path)")
        }
    }
    
    /// Get storage info
    func getStorageInfo() async throws -> (systemUsed: String, systemTotal: String, percentage: Double) {
        let output = try await executeCommand("df -h / | tail -1 | awk '{print $3, $2, $5}'")
        let parts = output.components(separatedBy: " ")
        
        guard parts.count >= 3 else {
            return ("0 GB", "500 GB", 0)
        }
        
        let used = parts[0]
        let total = parts[1]
        let percentageStr = parts[2].replacingOccurrences(of: "%", with: "")
        let percentage = Double(percentageStr) ?? 0
        
        return (used, total, percentage)
    }
}
