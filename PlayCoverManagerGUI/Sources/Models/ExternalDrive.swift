//
//  ExternalDrive.swift
//  PlayCoverManagerGUI
//
//  External drive information model
//

import Foundation

struct ExternalDrive: Identifiable, Codable, Hashable {
    let id = UUID()
    let identifier: String  // diskX
    let name: String
    let path: String
    let capacity: String
    let available: String
    
    enum CodingKeys: String, CodingKey {
        case identifier, name, path, capacity, available
    }
}
