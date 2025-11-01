//
//  QuickLauncherView.swift
//  PlayCoverManagerGUI
//
//  Quick launcher view with app grid
//

import SwiftUI

struct QuickLauncherView: View {
    @StateObject private var viewModel = QuickLauncherViewModel()
    @State private var viewMode: ViewMode = .grid
    @State private var searchText: String = ""
    
    enum ViewMode {
        case grid, list
    }
    
    var filteredApps: [PlayCoverApp] {
        if searchText.isEmpty {
            return viewModel.apps
        } else {
            return viewModel.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if viewModel.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                emptyStateView
            } else {
                if viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
        .alert("エラー", isPresented: $viewModel.showingLaunchError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
        }
        .task {
            await viewModel.refreshApps()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("🚀 クイックランチャー")
                .font(.title2)
                .bold()
            
            Spacer()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("アプリを検索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // View mode toggle
            Picker("", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                Image(systemName: "list.bullet").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            
            // Refresh button
            Button(action: {
                Task {
                    await viewModel.refreshApps()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 350), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(filteredApps) { app in
                    AppCardView(app: app) {
                        Task {
                            await viewModel.launchApp(app)
                        }
                    }
                    .contextMenu {
                        appContextMenu(app)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List(filteredApps) { app in
            AppListRowView(app: app) {
                Task {
                    await viewModel.launchApp(app)
                }
            }
            .contextMenu {
                appContextMenu(app)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("アプリがありません")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("PlayCoverでiOSアプリをインストールしてください")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("アプリ管理へ") {
                AppState.shared.selectedTab = .appManagement
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func appContextMenu(_ app: PlayCoverApp) -> some View {
        Button {
            Task {
                await viewModel.launchApp(app)
            }
        } label: {
            Label("起動", systemImage: "play.fill")
        }
        
        Divider()
        
        Button {
            viewModel.openInFinder(app)
        } label: {
            Label("Finderで表示", systemImage: "folder.fill")
        }
        
        Button {
            viewModel.showAppSettings(app)
        } label: {
            Label("設定", systemImage: "gearshape")
        }
        
        Divider()
        
        Button(role: .destructive) {
            Task {
                await viewModel.deleteApp(app)
            }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}

#Preview {
    QuickLauncherView()
        .frame(width: 900, height: 600)
}
