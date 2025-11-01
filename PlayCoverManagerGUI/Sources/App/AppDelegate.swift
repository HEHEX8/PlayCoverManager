//
//  AppDelegate.swift
//  PlayCoverManagerGUI
//
//  Single instance control and app lifecycle management
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let lockFileName = "playcover-manager-gui-running.lock"
    private var lockFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(lockFileName)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance check
        if isAnotherInstanceRunning() {
            activateExistingInstance()
            NSApp.terminate(nil)
            return
        }
        
        // Create lock file with current process ID
        createLockFile()
        
        // Disable automatic window restoration
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up lock file
        removeLockFile()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Single Instance Control
    
    private func isAnotherInstanceRunning() -> Bool {
        guard FileManager.default.fileExists(atPath: lockFileURL.path) else {
            return false
        }
        
        // Read PID from lock file
        guard let pidString = try? String(contentsOf: lockFileURL, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            // Invalid lock file, consider it stale
            return false
        }
        
        // Check if process exists
        let result = kill(pid, 0)
        if result == 0 {
            // Process exists
            return true
        } else {
            // Process doesn't exist, stale lock
            try? FileManager.default.removeItem(at: lockFileURL)
            return false
        }
    }
    
    private func activateExistingInstance() {
        // Try to activate existing window using AppleScript
        let script = """
        tell application "System Events"
            set processList to every process whose name is "PlayCoverManagerGUI"
            if (count of processList) > 0 then
                set frontmost of first item of processList to true
            end if
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        
        // Show alert
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "PlayCover Manager は既に実行中です"
            alert.informativeText = "既存のウィンドウを使用してください。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func createLockFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let pidString = "\(pid)\n"
        
        try? pidString.write(to: lockFileURL, atomically: true, encoding: .utf8)
    }
    
    private func removeLockFile() {
        try? FileManager.default.removeItem(at: lockFileURL)
    }
}
