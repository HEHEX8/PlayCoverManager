//
//  MaintenanceView.swift
//  PlayCoverManagerGUI
//
//  System maintenance view
//

import SwiftUI

struct MaintenanceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🔧 システムメンテナンス")
                .font(.title)
                .bold()
            
            Text("APFSスナップショット削除・キャッシュクリア")
                .foregroundColor(.secondary)
            
            Text("実装予定")
                .foregroundColor(.orange)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MaintenanceView()
}
