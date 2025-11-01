//
//  VolumeListView.swift
//  PlayCoverManagerGUI
//
//  Graphical volume operations with visual controls
//

import SwiftUI

struct VolumeListView: View {
    @StateObject private var viewModel = VolumeViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Actions
                    quickActionsSection
                    
                    // Volumes List
                    volumesSection
                }
                .padding(24)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ボリューム操作")
                    .font(.title2)
                    .bold()
                Text("外部ストレージのマウント・アンマウント管理")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                Task {
                    await viewModel.refreshVolumes()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Mount All
                QuickActionButton(
                    icon: "arrow.up.circle.fill",
                    title: "すべてマウント",
                    subtitle: "\(viewModel.unmountedCount)個のボリューム",
                    color: .green,
                    isEnabled: viewModel.unmountedCount > 0
                ) {
                    Task {
                        await viewModel.mountAll()
                    }
                }
                
                // Unmount All
                QuickActionButton(
                    icon: "arrow.down.circle.fill",
                    title: "すべてアンマウント",
                    subtitle: "\(viewModel.mountedCount)個のボリューム",
                    color: .orange,
                    isEnabled: viewModel.mountedCount > 0
                ) {
                    Task {
                        await viewModel.unmountAll()
                    }
                }
                
                // Eject Disk
                QuickActionButton(
                    icon: "eject.circle.fill",
                    title: "ディスク取り外し",
                    subtitle: "安全に取り外す",
                    color: .blue,
                    isEnabled: viewModel.mountedCount > 0
                ) {
                    Task {
                        await viewModel.ejectDisk()
                    }
                }
            }
        }
    }
    
    // MARK: - Volumes Section
    
    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ボリューム一覧")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.volumes.count) 個")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if viewModel.volumes.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.volumes) { volume in
                        VolumeCard(volume: volume, viewModel: viewModel)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("ボリュームが見つかりません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("PlayCover用の外部ボリュームを作成してください")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isEnabled ? color : .gray)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isHovered ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 5)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onHover { hovering in
            isHovered = hovering && isEnabled
        }
    }
}

// MARK: - Volume Card
struct VolumeCard: View {
    let volume: VolumeInfo
    @ObservedObject var viewModel: VolumeViewModel
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(volume.isMounted ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: volume.isMounted ? "externaldrive.fill.badge.checkmark" : "externaldrive.fill")
                    .font(.title2)
                    .foregroundColor(volume.isMounted ? .green : .gray)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(volume.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label(volume.app, systemImage: "app.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if volume.isMounted {
                        Label("マウント済み", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("未マウント", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Storage info
            VStack(alignment: .trailing, spacing: 4) {
                Text(volume.usedSpace)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("/ \(volume.totalSpace)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Actions
            HStack(spacing: 8) {
                if volume.isMounted {
                    // Unmount button
                    Button(action: {
                        Task {
                            await viewModel.unmountVolume(volume)
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("アンマウント")
                } else {
                    // Mount button
                    Button(action: {
                        Task {
                            await viewModel.mountVolume(volume)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help("マウント")
                }
                
                // More options
                Menu {
                    Button("Finderで表示") {
                        viewModel.openInFinder(volume)
                    }
                    
                    Button("再マウント") {
                        Task {
                            await viewModel.remountVolume(volume)
                        }
                    }
                    
                    Divider()
                    
                    Button("情報", action: {
                        viewModel.showVolumeInfo(volume)
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isHovered ? (volume.isMounted ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 5)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Models
struct VolumeInfo: Identifiable {
    let id = UUID()
    let name: String
    let app: String
    var isMounted: Bool
    let totalSpace: String
    let usedSpace: String
    let mountPath: String?
}

// MARK: - View Model
@MainActor
class VolumeViewModel: ObservableObject {
    @Published var volumes: [VolumeInfo] = [
        VolumeInfo(
            name: "PlayCover-StarRail",
            app: "崩壊：スターレイル",
            isMounted: true,
            totalSpace: "100 GB",
            usedSpace: "45 GB",
            mountPath: "/Volumes/PlayCover-StarRail"
        ),
        VolumeInfo(
            name: "PlayCover-Genshin",
            app: "原神",
            isMounted: false,
            totalSpace: "80 GB",
            usedSpace: "25 GB",
            mountPath: nil
        ),
        VolumeInfo(
            name: "PlayCover-Zenless",
            app: "ゼンレスゾーンゼロ",
            isMounted: true,
            totalSpace: "60 GB",
            usedSpace: "35 GB",
            mountPath: "/Volumes/PlayCover-Zenless"
        )
    ]
    @Published var isLoading = false
    
    var mountedCount: Int {
        volumes.filter { $0.isMounted }.count
    }
    
    var unmountedCount: Int {
        volumes.filter { !$0.isMounted }.count
    }
    
    func refreshVolumes() async {
        isLoading = true
        try? await Task.sleep(for: .seconds(1))
        // TODO: Load from shell script
        isLoading = false
    }
    
    func mountAll() async {
        for index in volumes.indices where !volumes[index].isMounted {
            try? await Task.sleep(for: .milliseconds(500))
            volumes[index].isMounted = true
        }
    }
    
    func unmountAll() async {
        for index in volumes.indices where volumes[index].isMounted {
            try? await Task.sleep(for: .milliseconds(500))
            volumes[index].isMounted = false
        }
    }
    
    func ejectDisk() async {
        await unmountAll()
        // TODO: Eject physical disk
    }
    
    func mountVolume(_ volume: VolumeInfo) async {
        if let index = volumes.firstIndex(where: { $0.id == volume.id }) {
            try? await Task.sleep(for: .seconds(1))
            volumes[index].isMounted = true
        }
    }
    
    func unmountVolume(_ volume: VolumeInfo) async {
        if let index = volumes.firstIndex(where: { $0.id == volume.id }) {
            try? await Task.sleep(for: .seconds(1))
            volumes[index].isMounted = false
        }
    }
    
    func remountVolume(_ volume: VolumeInfo) async {
        await unmountVolume(volume)
        try? await Task.sleep(for: .milliseconds(500))
        await mountVolume(volume)
    }
    
    func openInFinder(_ volume: VolumeInfo) {
        guard let path = volume.mountPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    
    func showVolumeInfo(_ volume: VolumeInfo) {
        // TODO: Show info sheet
    }
}

#Preview {
    VolumeListView()
        .frame(width: 900, height: 600)
}
