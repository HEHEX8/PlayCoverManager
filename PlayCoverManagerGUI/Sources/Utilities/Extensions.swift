//
//  Extensions.swift
//  PlayCoverManagerGUI
//
//  Utility extensions
//

import Foundation
import SwiftUI

// MARK: - String Extensions
extension String {
    /// Convert bytes string to human readable format
    static func bytesToHuman(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }
}

// MARK: - FileManager Extensions
extension FileManager {
    /// Get size of directory
    func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        guard let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            size += Int64(fileSize)
        }
        
        return size
    }
    
    /// Check if path exists and is directory
    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}

// MARK: - View Extensions
extension View {
    /// Apply conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
