//
//  AppListRowView.swift
//  PlayCoverManagerGUI
//
//  List row view for app in list layout
//

import SwiftUI

struct AppListRowView: View {
    let app: PlayCoverApp
    let onLaunch: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Star indicator
            if app.isRecentlyLaunched {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.body)
            } else {
                Color.clear
                    .frame(width: 16)
            }
            
            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(app.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Storage badge
            HStack(spacing: 4) {
                Image(systemName: app.storageIcon)
                    .foregroundColor(app.storageColor)
                    .font(.caption)
                
                Text(app.storageMode == .external ? "外部" : "内蔵")
                    .font(.caption)
                    .foregroundColor(app.storageColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(app.storageColor.opacity(0.1))
            .cornerRadius(4)
            
            // Status badge
            HStack(spacing: 4) {
                Image(systemName: app.status.icon)
                    .foregroundColor(app.status.color)
                    .font(.caption)
                
                Text(app.status.displayText)
                    .font(.caption)
                    .foregroundColor(app.status.color)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(app.status.color.opacity(0.1))
            .cornerRadius(4)
            
            // Sudo indicator
            if app.requiresSudo {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            // Launch button
            Button(action: onLaunch) {
                Image(systemName: "play.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        AppListRowView(app: PlayCoverApp.sampleApps[0]) {
            print("Launch app")
        }
        
        AppListRowView(app: PlayCoverApp.sampleApps[1]) {
            print("Launch app")
        }
        
        AppListRowView(app: PlayCoverApp.sampleApps[2]) {
            print("Launch app")
        }
    }
}
