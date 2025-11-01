//
//  SidebarView.swift
//  PlayCoverManagerGUI
//
//  Navigation sidebar
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(AppState.Tab.allCases, id: \.self, selection: $appState.selectedTab) { tab in
            NavigationLink(value: tab) {
                Label(tab.rawValue, systemImage: tab.icon)
            }
        }
        .navigationTitle("PlayCover Manager")
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState.shared)
        .frame(width: 220, height: 600)
}
