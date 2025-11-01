//
//  SettingsView.swift
//  PlayCoverManagerGUI
//
//  Settings view
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("⚙️ 設定")
                .font(.title)
                .bold()
            
            Text("アプリの設定・環境設定")
                .foregroundColor(.secondary)
            
            Text("実装予定")
                .foregroundColor(.orange)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
