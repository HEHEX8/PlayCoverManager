//
//  VolumeInfo.swift
//  PlayCoverManagerGUI
//
//  Volume information model
//

import Foundation

struct VolumeInfo: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let app: String
    var isMounted: Bool
    let totalSpace: String
    let usedSpace: String
    let mountPath: String?
    
    enum CodingKeys: String, CodingKey {
        case name, app, isMounted, totalSpace, usedSpace, mountPath
    }
}
