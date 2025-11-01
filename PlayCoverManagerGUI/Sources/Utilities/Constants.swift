//
//  Constants.swift
//  PlayCoverManagerGUI
//
//  App constants
//

import Foundation

enum AppConstants {
    static let appName = "PlayCover Manager"
    static let version = "6.0.0-alpha1"
    static let bundleId = "io.playcover.PlayCoverManager"
    
    // Paths
    static let playCoverBundleId = "io.playcover.PlayCover"
    static let playCoverBase = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers")
    static let playCoverContainer = playCoverBase
        .appendingPathComponent(playCoverBundleId)
    static let playCoverAppsDir = playCoverContainer
        .appendingPathComponent("Applications")
    
    // Volume
    static let playCoverVolumeName = "PlayCover"
    
    // Data directory
    static let dataDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/PlayCover Manager")
    static let mappingFile = dataDirectory
        .appendingPathComponent("mapping-file.txt")
    static let recentAppFile = dataDirectory
        .appendingPathComponent("recent-app")
}
