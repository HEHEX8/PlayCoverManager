//
//  AppManagementView.swift
//  PlayCoverManagerGUI
//
//  App management view for installing/uninstalling apps
//

import SwiftUI

struct AppManagementView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("📦 アプリ管理")
                .font(.title)
                .bold()
            
            Text("IPA インストール・アンインストール機能")
                .foregroundColor(.secondary)
            
            Text("実装予定")
                .foregroundColor(.orange)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppManagementView()
}
