//
//  AppManagementView.swift
//  PlayCoverManagerGUI
//
//  Graphical app management with drag & drop
//

import SwiftUI
import UniformTypeIdentifiers

struct AppManagementView: View {
    @StateObject private var viewModel = AppManagementViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if viewModel.isInstalling {
                installingView
            } else {
                mainContent
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("アプリ管理")
                    .font(.title2)
                    .bold()
                Text("IPAファイルをドラッグ&ドロップしてインストール")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Drag & Drop Zone
                dragDropZone
                
                // Installed Apps Section
                if !viewModel.installedApps.isEmpty {
                    installedAppsSection
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Drag & Drop Zone
    
    private var dragDropZone: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: viewModel.isDragOver ? "arrow.down.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.accentColor)
            }
            .shadow(color: .accentColor.opacity(0.2), radius: 20)
            
            // Text
            VStack(spacing: 8) {
                Text(viewModel.isDragOver ? "ここにドロップ" : "IPAファイルをドロップ")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("または")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    viewModel.selectIPAFiles()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("ファイルを選択...")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
                .foregroundColor(viewModel.isDragOver ? .accentColor : .secondary.opacity(0.3))
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(viewModel.isDragOver ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.isDragOver)
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDragOver) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - Installed Apps Section
    
    private var installedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("インストール済み")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.installedApps.count) 個")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(viewModel.installedApps) { app in
                    InstalledAppCard(app: app) {
                        viewModel.uninstallApp(app)
                    }
                }
            }
        }
    }
    
    // MARK: - Installing View
    
    private var installingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            
            // Progress
            VStack(spacing: 12) {
                Text("インストール中...")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let currentFile = viewModel.currentInstallingFile {
                    Text(currentFile)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: viewModel.installProgress)
                    .frame(width: 300)
                
                Text("\(Int(viewModel.installProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Installed App Card
struct InstalledAppCard: View {
    let app: PlayCoverApp
    let onUninstall: () -> Void
    
    @State private var isHovered = false
    @State private var showingUninstallConfirm = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(app.status.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: app.storageIcon)
                    .font(.title3)
                    .foregroundColor(app.storageColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(app.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Uninstall button (shown on hover)
            if isHovered {
                Button(action: {
                    showingUninstallConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .alert("アプリを削除", isPresented: $showingUninstallConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                onUninstall()
            }
        } message: {
            Text("\(app.name) を削除してもよろしいですか？この操作は取り消せません。")
        }
    }
}

// MARK: - View Model
@MainActor
class AppManagementViewModel: ObservableObject {
    @Published var installedApps: [PlayCoverApp] = PlayCoverApp.sampleApps
    @Published var isDragOver = false
    @Published var isInstalling = false
    @Published var installProgress: Double = 0.0
    @Published var currentInstallingFile: String?
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url, url.pathExtension == "ipa" else { return }
                
                Task { @MainActor in
                    await self.installIPA(url: url)
                }
            }
        }
        return true
    }
    
    func selectIPAFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "ipa")!]
        panel.message = "インストールするIPAファイルを選択してください"
        
        panel.begin { response in
            guard response == .OK else { return }
            
            Task { @MainActor in
                for url in panel.urls {
                    await self.installIPA(url: url)
                }
            }
        }
    }
    
    func installIPA(url: URL) async {
        isInstalling = true
        currentInstallingFile = url.lastPathComponent
        installProgress = 0.0
        
        // Simulate installation progress
        for i in 1...100 {
            try? await Task.sleep(for: .milliseconds(30))
            installProgress = Double(i) / 100.0
        }
        
        // TODO: Actual installation via ShellScriptExecutor
        
        isInstalling = false
        currentInstallingFile = nil
    }
    
    func uninstallApp(_ app: PlayCoverApp) {
        // TODO: Actual uninstallation
        if let index = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps.remove(at: index)
        }
    }
}

#Preview {
    AppManagementView()
        .frame(width: 900, height: 600)
}
