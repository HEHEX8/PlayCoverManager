//
//  SettingsView.swift
//  PlayCoverManagerGUI
//
//  Graphical settings with visual controls
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerView
                
                // Transfer Method
                transferMethodSection
                
                // Appearance
                appearanceSection
                
                // Notifications
                notificationsSection
                
                // Advanced
                advancedSection
                
                // About
                aboutSection
            }
            .padding(24)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("設定")
                    .font(.title2)
                    .bold()
                Text("アプリケーションの動作をカスタマイズ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Transfer Method Section
    
    private var transferMethodSection: some View {
        SettingsSection(title: "転送方法", icon: "arrow.left.arrow.right.circle.fill", color: .blue) {
            VStack(spacing: 12) {
                ForEach(TransferMethod.allCases, id: \.self) { method in
                    TransferMethodCard(
                        method: method,
                        isSelected: viewModel.transferMethod == method,
                        onSelect: {
                            viewModel.transferMethod = method
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        SettingsSection(title: "外観", icon: "paintbrush.fill", color: .purple) {
            VStack(spacing: 16) {
                // Theme selector
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: viewModel.theme == theme,
                            onSelect: {
                                viewModel.theme = theme
                            }
                        )
                    }
                }
                
                Divider()
                
                // Accent color
                HStack {
                    Label("アクセントカラー", systemImage: "paintpalette.fill")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    ColorPicker("", selection: $viewModel.accentColor)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        SettingsSection(title: "通知", icon: "bell.fill", color: .orange) {
            VStack(spacing: 16) {
                ToggleRow(
                    icon: "checkmark.circle.fill",
                    title: "インストール完了",
                    subtitle: "IPAインストールが完了したら通知",
                    color: .green,
                    isOn: $viewModel.notifyOnInstallComplete
                )
                
                ToggleRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "エラー通知",
                    subtitle: "エラーが発生したら通知",
                    color: .red,
                    isOn: $viewModel.notifyOnError
                )
                
                ToggleRow(
                    icon: "arrow.down.circle.fill",
                    title: "マウント/アンマウント",
                    subtitle: "ボリューム操作時に通知",
                    color: .blue,
                    isOn: $viewModel.notifyOnVolumeOperation
                )
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        SettingsSection(title: "詳細設定", icon: "gearshape.2.fill", color: .gray) {
            VStack(spacing: 16) {
                ToggleRow(
                    icon: "terminal.fill",
                    title: "詳細ログ",
                    subtitle: "デバッグ情報を表示",
                    color: .cyan,
                    isOn: $viewModel.verboseLogging
                )
                
                ToggleRow(
                    icon: "arrow.clockwise.circle.fill",
                    title: "自動リフレッシュ",
                    subtitle: "アプリリストを自動更新",
                    color: .purple,
                    isOn: $viewModel.autoRefresh
                )
                
                Divider()
                
                // Cache management
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("キャッシュ", systemImage: "tray.full.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("アプリ情報とボリューム状態のキャッシュ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("クリア") {
                        viewModel.clearCache()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsSection(title: "このアプリについて", icon: "info.circle.fill", color: .blue) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PlayCover Manager")
                            .font(.headline)
                        Text("バージョン 6.0.0-alpha1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("GitHub") {
                        viewModel.openGitHub()
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                HStack {
                    Text("© 2025 PlayCover Manager Team")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            VStack(spacing: 12) {
                content
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
}

// MARK: - Transfer Method Card
struct TransferMethodCard: View {
    let method: TransferMethod
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(method.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: method.icon)
                        .font(.body)
                        .foregroundColor(method.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (isHovered ? Color.gray.opacity(0.3) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.previewColor)
                        .frame(width: 60, height: 40)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
                
                Text(theme.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (isHovered ? Color.gray.opacity(0.3) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(12)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

// MARK: - Models
enum TransferMethod: String, CaseIterable {
    case rsync = "rsync"
    case cp = "cp"
    case ditto = "ditto"
    case parallel = "parallel"
    
    var name: String {
        switch self {
        case .rsync: return "rsync（推奨）"
        case .cp: return "cp"
        case .ditto: return "ditto"
        case .parallel: return "parallel"
        }
    }
    
    var description: String {
        switch self {
        case .rsync: return "安定性重視、再開可能"
        case .cp: return "高速（rsyncより20%速い）"
        case .ditto: return "macOS専用、リソースフォーク保持"
        case .parallel: return "最速（並列処理）"
        }
    }
    
    var icon: String {
        switch self {
        case .rsync: return "arrow.triangle.2.circlepath"
        case .cp: return "doc.on.doc"
        case .ditto: return "apple.logo"
        case .parallel: return "arrow.up.arrow.down"
        }
    }
    
    var color: Color {
        switch self {
        case .rsync: return .blue
        case .cp: return .green
        case .ditto: return .purple
        case .parallel: return .orange
        }
    }
}

enum AppTheme: String, CaseIterable {
    case auto = "auto"
    case light = "light"
    case dark = "dark"
    
    var name: String {
        switch self {
        case .auto: return "自動"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
    
    var previewColor: Color {
        switch self {
        case .auto: return Color(nsColor: .controlBackgroundColor)
        case .light: return .white
        case .dark: return .black
        }
    }
}

// MARK: - View Model
@MainActor
class SettingsViewModel: ObservableObject {
    private let defaults = UserDefaults.standard
    
    @Published var transferMethod: TransferMethod {
        didSet {
            defaults.set(transferMethod.rawValue, forKey: "transferMethod")
        }
    }
    
    @Published var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: "theme")
            applyTheme()
        }
    }
    
    @Published var accentColor: Color {
        didSet {
            saveAccentColor()
        }
    }
    
    @Published var notifyOnInstallComplete: Bool {
        didSet {
            defaults.set(notifyOnInstallComplete, forKey: "notifyOnInstallComplete")
        }
    }
    
    @Published var notifyOnError: Bool {
        didSet {
            defaults.set(notifyOnError, forKey: "notifyOnError")
        }
    }
    
    @Published var notifyOnVolumeOperation: Bool {
        didSet {
            defaults.set(notifyOnVolumeOperation, forKey: "notifyOnVolumeOperation")
        }
    }
    
    @Published var verboseLogging: Bool {
        didSet {
            defaults.set(verboseLogging, forKey: "verboseLogging")
        }
    }
    
    @Published var autoRefresh: Bool {
        didSet {
            defaults.set(autoRefresh, forKey: "autoRefresh")
        }
    }
    
    init() {
        // Load saved settings
        if let savedMethod = defaults.string(forKey: "transferMethod"),
           let method = TransferMethod(rawValue: savedMethod) {
            self.transferMethod = method
        } else {
            self.transferMethod = .rsync
        }
        
        if let savedTheme = defaults.string(forKey: "theme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.theme = theme
        } else {
            self.theme = .auto
        }
        
        self.accentColor = loadAccentColor()
        self.notifyOnInstallComplete = defaults.bool(forKey: "notifyOnInstallComplete") || !defaults.object(forKey: "notifyOnInstallComplete") as? Bool != nil
        self.notifyOnError = defaults.bool(forKey: "notifyOnError") || !defaults.object(forKey: "notifyOnError") as? Bool != nil
        self.notifyOnVolumeOperation = defaults.bool(forKey: "notifyOnVolumeOperation")
        self.verboseLogging = defaults.bool(forKey: "verboseLogging")
        self.autoRefresh = defaults.bool(forKey: "autoRefresh") || !defaults.object(forKey: "autoRefresh") as? Bool != nil
        
        applyTheme()
    }
    
    private func loadAccentColor() -> Color {
        if let data = defaults.data(forKey: "accentColor"),
           let components = try? JSONDecoder().decode([Double].self, from: data) {
            return Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
        }
        return .blue
    }
    
    private func saveAccentColor() {
        if let components = accentColor.cgColor?.components {
            let data = try? JSONEncoder().encode(components)
            defaults.set(data, forKey: "accentColor")
        }
    }
    
    private func applyTheme() {
        switch theme {
        case .auto:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    func clearCache() {
        Task {
            do {
                try await ShellScriptExecutor.shared.clearSystemCache()
                print("Cache cleared successfully")
            } catch {
                print("Failed to clear cache: \(error)")
            }
        }
    }
    
    func openGitHub() {
        if let url = URL(string: "https://github.com/HEHEX8/PlayCoverManager") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 700, height: 800)
}
