//
//  PlayCoverApp.swift
//  PlayCoverManagerGUI
//
//  Model for PlayCover installed apps
//

import Foundation
import SwiftUI

// Storage mode detection
enum StorageMode: String, Codable {
    case external = "external"
    case externalWrongLocation = "external_wrong_location"
    case internalIntentional = "internal_intentional"
    case internalIntentionalEmpty = "internal_intentional_empty"
    case internalContaminated = "internal_contaminated"
    case none = "none"
}

// App status for quick launcher
enum AppStatus: String, Codable {
    case ready = "ready"
    case unmounted = "unmounted"
    case needsRemount = "needs_remount"
    case warning = "warning"
    case empty = "empty"
    
    var icon: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .unmounted:
            return "shippingbox.fill"
        case .needsRemount:
            return "arrow.triangle.2.circlepath"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .empty:
            return "tray.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .ready:
            return .green
        case .unmounted:
            return .blue
        case .needsRemount:
            return .orange
        case .warning:
            return .red
        case .empty:
            return .gray
        }
    }
    
    var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .unmounted:
            return "未マウント"
        case .needsRemount:
            return "要再マウント"
        case .warning:
            return "内蔵データ検出"
        case .empty:
            return "初期状態"
        }
    }
}

struct PlayCoverApp: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bundleId: String
    let volumeName: String
    let containerPath: String
    var storageMode: StorageMode
    var status: AppStatus
    var size: String
    var requiresSudo: Bool
    var isRecentlyLaunched: Bool
    
    var storageIcon: String {
        switch storageMode {
        case .external, .externalWrongLocation:
            return "externaldrive.fill"
        case .internalIntentional, .internalIntentionalEmpty, .internalContaminated:
            return "internaldrive.fill"
        case .none:
            return "questionmark.circle.fill"
        }
    }
    
    var storageColor: Color {
        switch storageMode {
        case .external:
            return .blue
        case .externalWrongLocation:
            return .orange
        case .internalIntentional, .internalIntentionalEmpty:
            return .purple
        case .internalContaminated:
            return .red
        case .none:
            return .gray
        }
    }
    
    var storageDisplayText: String {
        switch storageMode {
        case .external:
            return "外部ストレージ"
        case .externalWrongLocation:
            return "外部（要再マウント）"
        case .internalIntentional:
            return "内蔵ストレージ"
        case .internalIntentionalEmpty:
            return "内蔵（データなし）"
        case .internalContaminated:
            return "内蔵（意図しないデータ）"
        case .none:
            return "未設定"
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleId: String,
        volumeName: String,
        containerPath: String,
        storageMode: StorageMode = .none,
        status: AppStatus = .empty,
        size: String = "0 B",
        requiresSudo: Bool = false,
        isRecentlyLaunched: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.volumeName = volumeName
        self.containerPath = containerPath
        self.storageMode = storageMode
        self.status = status
        self.size = size
        self.requiresSudo = requiresSudo
        self.isRecentlyLaunched = isRecentlyLaunched
    }
}

// MARK: - Sample Data for Preview
extension PlayCoverApp {
    static let sampleApps: [PlayCoverApp] = [
        PlayCoverApp(
            name: "崩壊：スターレイル",
            bundleId: "com.mihoyo.starrail",
            volumeName: "PlayCover-StarRail",
            containerPath: "/Users/user/Library/Containers/com.mihoyo.starrail",
            storageMode: .external,
            status: .ready,
            size: "45 GB",
            requiresSudo: true,
            isRecentlyLaunched: true
        ),
        PlayCoverApp(
            name: "原神",
            bundleId: "com.mihoyo.genshin",
            volumeName: "PlayCover-Genshin",
            containerPath: "/Users/user/Library/Containers/com.mihoyo.genshin",
            storageMode: .internalContaminated,
            status: .warning,
            size: "25 GB",
            requiresSudo: false,
            isRecentlyLaunched: false
        ),
        PlayCoverApp(
            name: "ゼンレスゾーンゼロ",
            bundleId: "com.mihoyo.zenless",
            volumeName: "PlayCover-Zenless",
            containerPath: "/Users/user/Library/Containers/com.mihoyo.zenless",
            storageMode: .external,
            status: .unmounted,
            size: "35 GB",
            requiresSudo: true,
            isRecentlyLaunched: false
        )
    ]
}
