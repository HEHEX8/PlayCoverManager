//
//  AppCardView.swift
//  PlayCoverManagerGUI
//
//  Card view for app in grid layout
//

import SwiftUI

struct AppCardView: View {
    let app: PlayCoverApp
    let onLaunch: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and recently launched indicator
            HStack(alignment: .top) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if app.isRecentlyLaunched {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            // Storage and status badges
            HStack(spacing: 8) {
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
                
                Spacer()
                
                // Sudo indicator
                if app.requiresSudo {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            // Size
            Text("容量: \(app.size)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Launch button
            Button(action: onLaunch) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("起動")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    HStack(spacing: 16) {
        AppCardView(app: PlayCoverApp.sampleApps[0]) {
            print("Launch app")
        }
        .frame(width: 280)
        
        AppCardView(app: PlayCoverApp.sampleApps[1]) {
            print("Launch app")
        }
        .frame(width: 280)
    }
    .padding()
}
