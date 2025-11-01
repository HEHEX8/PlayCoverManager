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
    
    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "スクリプトが見つかりません: \(path)"
        case .executionFailed(let code, let message):
            return "実行エラー (コード: \(code)): \(message)"
        case .invalidOutput(let message):
            return "出力の解析エラー: \(message)"
        }
    }
}

@MainActor
class ShellScriptExecutor: ObservableObject {
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
        if let environment = environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }
        
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

// MARK: - Convenience Methods
extension ShellScriptExecutor {
    /// Get list of installed apps
    func getInstalledApps() async throws -> [PlayCoverApp] {
        let output = try await execute(script: "main.sh", arguments: ["list-apps"])
        
        // Parse output and create PlayCoverApp objects
        // TODO: Implement parsing logic
        
        return []
    }
    
    /// Launch an app
    func launchApp(bundleId: String) async throws {
        _ = try await execute(script: "main.sh", arguments: ["launch", bundleId])
    }
    
    /// Mount a volume
    func mountVolume(volumeName: String) async throws {
        _ = try await execute(script: "main.sh", arguments: ["mount", volumeName])
    }
    
    /// Unmount a volume
    func unmountVolume(volumeName: String) async throws {
        _ = try await execute(script: "main.sh", arguments: ["unmount", volumeName])
    }
}
