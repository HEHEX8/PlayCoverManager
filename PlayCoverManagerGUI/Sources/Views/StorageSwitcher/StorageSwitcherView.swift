//
//  StorageSwitcherView.swift
//  PlayCoverManagerGUI
//
//  Storage location switcher: Internal ⇄ External
//

import SwiftUI

struct StorageSwitcherView: View {
    @StateObject private var viewModel = StorageSwitcherViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if viewModel.isTransferring {
                transferringView
            } else {
                mainContent
            }
        }
        .alert("エラー", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラー")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ストレージ切り替え")
                    .font(.title2)
                    .bold()
                Text("内蔵ストレージ ⇄ 外部ストレージの切り替え")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                Task {
                    await viewModel.refreshApps()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info section
                infoSection
                
                // Apps list
                if !viewModel.switchableApps.isEmpty {
                    appsListSection
                } else {
                    emptyStateView
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Internal storage info
                StorageInfoCard(
                    icon: "internaldrive.fill",
                    title: "内蔵ストレージ",
                    free: viewModel.internalFree,
                    color: .purple
                )
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                // External storage info
                StorageInfoCard(
                    icon: "externaldrive.fill",
                    title: "外部ストレージ",
                    free: viewModel.externalFree,
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Apps List Section
    
    private var appsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("切り替え可能なアプリ")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.switchableApps.count) 個")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.switchableApps) { app in
                    SwitchableAppCard(
                        app: app,
                        onSwitch: {
                            viewModel.selectedApp = app
                            viewModel.showingSwitchConfirm = true
                        }
                    )
                }
            }
        }
        .alert("ストレージを切り替え", isPresented: $viewModel.showingSwitchConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("切り替え", role: .destructive) {
                Task {
                    await viewModel.switchStorage()
                }
            }
        } message: {
            if let app = viewModel.selectedApp {
                let from = app.storageMode == .external || app.storageMode == .externalWrongLocation ? "外部" : "内蔵"
                let to = from == "外部" ? "内蔵" : "外部"
                Text("\(app.name) のストレージを\(from)から\(to)に切り替えますか？\n\nデータは安全に転送されます。")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("切り替え可能なアプリはありません")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("すべてのアプリが適切な場所に配置されています")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Transferring View
    
    private var transferringView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated transfer icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            
            // Transfer info
            VStack(spacing: 16) {
                if let app = viewModel.selectedApp {
                    Text("転送中...")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(app.name)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.transferDirection == .toExternal ? "externaldrive.fill" : "internaldrive.fill")
                        Text(viewModel.transferDirection == .toExternal ? "外部ストレージへ移動中" : "内蔵ストレージへ移動中")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.transferProgress)
                        .frame(width: 400)
                    
                    HStack {
                        Text("\(Int(viewModel.transferProgress * 100))%")
                            .font(.caption)
                        
                        Spacer()
                        
                        if let speed = viewModel.transferSpeed {
                            Text(speed)
                                .font(.caption)
                        }
                        
                        if let eta = viewModel.transferETA {
                            Text("残り \(eta)")
                                .font(.caption)
                        }
                    }
                    .frame(width: 400)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("このウィンドウを閉じないでください")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Storage Info Card
struct StorageInfoCard: View {
    let icon: String
    let title: String
    let free: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text("空き容量")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(free)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
}

// MARK: - Switchable App Card
struct SwitchableAppCard: View {
    let app: PlayCoverApp
    let onSwitch: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(app.storageColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: app.storageIcon)
                    .font(.title2)
                    .foregroundColor(app.storageColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(app.storageDisplayText)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive")
                        Text(app.size)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Switch button
            Button(action: onSwitch) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("切り替え")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 5)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    StorageSwitcherView()
        .frame(width: 900, height: 600)
}
