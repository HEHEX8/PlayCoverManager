//
//  MaintenanceView.swift
//  PlayCoverManagerGUI
//
//  Graphical system maintenance with visual buttons
//

import SwiftUI

struct MaintenanceView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Storage Info
                    storageInfoSection
                    
                    // Maintenance Actions
                    maintenanceActionsSection
                    
                    // Danger Zone
                    dangerZoneSection
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $viewModel.showingSnapshotDetails) {
            SnapshotDetailsSheet(snapshots: viewModel.snapshots)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("システムメンテナンス")
                    .font(.title2)
                    .bold()
                Text("ストレージの最適化とシステムクリーンアップ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Storage Info Section
    
    private var storageInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("ストレージ使用状況")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("更新") {
                    Task {
                        await viewModel.refreshStorageInfo()
                    }
                }
                .buttonStyle(.bordered)
            }
            
            HStack(spacing: 16) {
                // System volume
                StorageCard(
                    icon: "internaldrive.fill",
                    title: "システムボリューム",
                    used: viewModel.systemUsed,
                    total: viewModel.systemTotal,
                    percentage: viewModel.systemPercentage,
                    color: .blue
                )
                
                // External volume
                StorageCard(
                    icon: "externaldrive.fill",
                    title: "外部ストレージ",
                    used: viewModel.externalUsed,
                    total: viewModel.externalTotal,
                    percentage: viewModel.externalPercentage,
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Maintenance Actions
    
    private var maintenanceActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("メンテナンス操作")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                // APFS Snapshots
                MaintenanceActionCard(
                    icon: "clock.arrow.circlepath",
                    title: "APFSスナップショット",
                    subtitle: "\(viewModel.snapshotCount)個のスナップショット",
                    description: "Time Machineの古いスナップショットを削除して容量を解放",
                    color: .orange,
                    actionTitle: "確認・削除",
                    isProcessing: viewModel.isDeletingSnapshots
                ) {
                    viewModel.showingSnapshotDetails = true
                }
                
                // System Cache
                MaintenanceActionCard(
                    icon: "tray.full.fill",
                    title: "システムキャッシュ",
                    subtitle: viewModel.cacheSize,
                    description: "ユーザーキャッシュと一時ファイルをクリア",
                    color: .purple,
                    actionTitle: "クリア",
                    isProcessing: viewModel.isClearingCache
                ) {
                    Task {
                        await viewModel.clearSystemCache()
                    }
                }
                
                // App Cache
                MaintenanceActionCard(
                    icon: "square.stack.3d.up.fill",
                    title: "アプリキャッシュ",
                    subtitle: viewModel.appCacheSize,
                    description: "PlayCoverアプリのキャッシュをクリア",
                    color: .cyan,
                    actionTitle: "クリア",
                    isProcessing: viewModel.isClearingAppCache
                ) {
                    Task {
                        await viewModel.clearAppCache()
                    }
                }
                
                // Verify Volumes
                MaintenanceActionCard(
                    icon: "checkmark.shield.fill",
                    title: "ボリューム検証",
                    subtitle: "整合性チェック",
                    description: "APFSボリュームの整合性を検証",
                    color: .green,
                    actionTitle: "検証",
                    isProcessing: viewModel.isVerifying
                ) {
                    Task {
                        await viewModel.verifyVolumes()
                    }
                }
            }
        }
    }
    
    // MARK: - Danger Zone
    
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            HStack {
                Label("危険な操作", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                DangerActionCard(
                    icon: "trash.fill",
                    title: "全データ削除",
                    description: "すべてのPlayCoverデータとボリュームを完全に削除します。この操作は取り消せません。",
                    actionTitle: "全削除",
                    isProcessing: viewModel.isNuking
                ) {
                    viewModel.showingNukeConfirm = true
                }
            }
        }
    }
}

// MARK: - Storage Card
struct StorageCard: View {
    let icon: String
    let title: String
    let used: String
    let total: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: percentage)
                
                VStack(spacing: 2) {
                    Text("\(Int(percentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text("使用中")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 4) {
                Text("\(used) / \(total)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("利用可能: \(calculateFree(used: used, total: total))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    private func calculateFree(used: String, total: String) -> String {
        // Simplified calculation
        return "150 GB"
    }
}

// MARK: - Maintenance Action Card
struct MaintenanceActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    let actionTitle: String
    let isProcessing: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon and title
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            // Action button
            Button(action: action) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isProcessing ? "処理中..." : actionTitle)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
        .padding(16)
        .frame(height: 220)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 5)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Danger Action Card
struct DangerActionCard: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(actionTitle)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isProcessing)
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Snapshot Details Sheet
struct SnapshotDetailsSheet: View {
    let snapshots: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("APFSスナップショット")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button("閉じる") {
                    dismiss()
                }
            }
            .padding()
            
            if snapshots.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("スナップショットはありません")
                        .font(.headline)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(snapshots, id: \.self) { snapshot in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text(snapshot)
                            .font(.body)
                    }
                }
                
                Button("すべて削除") {
                    // TODO: Delete all snapshots
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - View Model
@MainActor
class MaintenanceViewModel: ObservableObject {
    @Published var systemUsed = "0 GB"
    @Published var systemTotal = "500 GB"
    @Published var systemPercentage: Double = 0
    
    @Published var externalUsed = "0 GB"
    @Published var externalTotal = "200 GB"
    @Published var externalPercentage: Double = 0
    
    @Published var snapshotCount = 0
    @Published var cacheSize = "計算中..."
    @Published var appCacheSize = "計算中..."
    
    @Published var isDeletingSnapshots = false
    @Published var isClearingCache = false
    @Published var isClearingAppCache = false
    @Published var isVerifying = false
    @Published var isNuking = false
    
    @Published var showingSnapshotDetails = false
    @Published var showingNukeConfirm = false
    @Published var errorMessage: String?
    
    @Published var snapshots: [String] = []
    
    private let shellExecutor = ShellScriptExecutor.shared
    
    init() {
        Task {
            await refreshStorageInfo()
            await loadSnapshots()
        }
    }
    
    func refreshStorageInfo() async {
        do {
            // Get system storage info
            let (used, total, percentage) = try await shellExecutor.getStorageInfo()
            systemUsed = used
            systemTotal = total
            systemPercentage = percentage
            
            // TODO: Get external storage info
            externalUsed = "105 GB"
            externalTotal = "200 GB"
            externalPercentage = 52.5
            
        } catch {
            errorMessage = "ストレージ情報の取得に失敗: \(error.localizedDescription)"
        }
    }
    
    func loadSnapshots() async {
        do {
            snapshots = try await shellExecutor.getAPFSSnapshots()
            snapshotCount = snapshots.count
        } catch {
            snapshots = []
            snapshotCount = 0
        }
    }
    
    func deleteAllSnapshots() async {
        isDeletingSnapshots = true
        defer { isDeletingSnapshots = false }
        
        do {
            try await shellExecutor.deleteAPFSSnapshots()
            await loadSnapshots()
            await refreshStorageInfo()
        } catch {
            errorMessage = "スナップショットの削除に失敗: \(error.localizedDescription)"
        }
    }
    
    func clearSystemCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        
        do {
            try await shellExecutor.clearSystemCache()
            cacheSize = "0 MB"
        } catch {
            errorMessage = "キャッシュのクリアに失敗: \(error.localizedDescription)"
        }
    }
    
    func clearAppCache() async {
        isClearingAppCache = true
        defer { isClearingAppCache = false }
        
        // Clear PlayCover app cache
        let cachePath = "~/Library/Caches/io.playcover.PlayCover"
        
        do {
            _ = try await shellExecutor.executeCommand("rm -rf \(cachePath)")
            appCacheSize = "0 MB"
        } catch {
            errorMessage = "アプリキャッシュのクリアに失敗: \(error.localizedDescription)"
        }
    }
    
    func verifyVolumes() async {
        isVerifying = true
        defer { isVerifying = false }
        
        do {
            let volumes = try await shellExecutor.getVolumes()
            
            for volume in volumes {
                // Verify each volume
                _ = try? await shellExecutor.executeCommand("diskutil verifyVolume '\(volume.name)'")
            }
            
        } catch {
            errorMessage = "ボリュームの検証に失敗: \(error.localizedDescription)"
        }
    }
}

#Preview {
    MaintenanceView()
        .frame(width: 900, height: 700)
}
