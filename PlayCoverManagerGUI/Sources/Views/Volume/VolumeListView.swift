//
//  VolumeListView.swift
//  PlayCoverManagerGUI
//
//  Volume operations view
//

import SwiftUI

struct VolumeListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("💾 ボリューム操作")
                .font(.title)
                .bold()
            
            Text("マウント・アンマウント・再マウント機能")
                .foregroundColor(.secondary)
            
            Text("実装予定")
                .foregroundColor(.orange)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VolumeListView()
}
