//
//  AppCardView.swift
//  PlayCoverManagerGUI
//
//  Graphical card view for app with hover effects
//

import SwiftUI

struct AppCardView: View {
    let app: PlayCoverApp
    let onLaunch: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Large icon area with gradient background
            ZStack {
                // Gradient background based on storage mode
                LinearGradient(
                    colors: [
                        app.storageColor.opacity(0.3),
                        app.storageColor.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 12) {
                    // Large app icon placeholder
                    ZStack {
                        Circle()
                            .fill(app.status.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: app.storageIcon)
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(app.storageColor)
                    }
                    .shadow(color: app.storageColor.opacity(0.3), radius: 10)
                    
                    // App name
                    Text(app.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                }
                .padding(.vertical, 20)
                
                // Recently launched star (top-right)
                if app.isRecentlyLaunched {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.title3)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                                .padding(12)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 180)
            
            // Info section
            VStack(spacing: 12) {
                // Status badges
                HStack(spacing: 8) {
                    // Status badge
                    StatusBadge(
                        icon: app.status.icon,
                        text: app.status.displayText,
                        color: app.status.color
                    )
                    
                    // Sudo badge
                    if app.requiresSudo {
                        StatusBadge(
                            icon: "lock.shield.fill",
                            text: "管理者",
                            color: .orange
                        )
                    }
                }
                
                // Storage info
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(app.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Launch button
                Button(action: onLaunch) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.body)
                        Text("起動")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(app.status == .ready ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(app.status == .empty)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isHovered ? app.storageColor.opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(
            color: .black.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 12 : 8,
            x: 0,
            y: isHovered ? 6 : 4
        )
        .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Status Badge Component
struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

#Preview {
    HStack(spacing: 20) {
        AppCardView(app: PlayCoverApp.sampleApps[0]) {
            print("Launch app")
        }
        .frame(width: 300)
        
        AppCardView(app: PlayCoverApp.sampleApps[1]) {
            print("Launch app")
        }
        .frame(width: 300)
    }
    .padding(40)
    .background(Color(nsColor: .windowBackgroundColor))
}
