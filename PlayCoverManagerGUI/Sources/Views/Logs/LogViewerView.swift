//
//  LogViewerView.swift
//  PlayCoverManagerGUI
//
//  Log viewer for system and app logs
//

import SwiftUI

struct LogViewerView: View {
    @StateObject private var viewModel = LogViewerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            headerView
            
            Divider()
            
            // Log content
            if viewModel.isLoading {
                ProgressView("ログを読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                logContentView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Log type selector
            Picker("", selection: $viewModel.selectedLogType) {
                ForEach(LogType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            Spacer()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("ログを検索...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(width: 250)
            
            // Clear button
            Button(action: {
                Task {
                    await viewModel.clearLogs()
                }
            }) {
                Label("クリア", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            
            // Refresh button
            Button(action: {
                Task {
                    await viewModel.refreshLogs()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Log Content
    
    private var logContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.filteredLogs) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: viewModel.filteredLogs.count) { _ in
                // Auto-scroll to bottom on new logs
                if viewModel.autoScroll, let lastLog = viewModel.filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(entry.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Level badge
            Text(entry.level.displayName)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.level.color.opacity(0.2))
                .foregroundColor(entry.level.color)
                .cornerRadius(4)
                .frame(width: 60)
            
            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(entry.level == .error ? Color.red.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Models

enum LogType: String, CaseIterable {
    case system = "system"
    case application = "application"
    case volume = "volume"
    case transfer = "transfer"
    
    var displayName: String {
        switch self {
        case .system: return "システム"
        case .application: return "アプリ"
        case .volume: return "ボリューム"
        case .transfer: return "転送"
        }
    }
}

enum LogLevel: String, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let type: LogType
    let message: String
    
    init(level: LogLevel, type: LogType, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.type = type
        self.message = message
    }
}

// MARK: - ViewModel

@MainActor
class LogViewerViewModel: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var selectedLogType: LogType = .system
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var autoScroll = true
    
    private let maxLogEntries = 1000
    
    init() {
        Task {
            await loadLogs()
        }
    }
    
    var filteredLogs: [LogEntry] {
        var filtered = logs.filter { $0.type == selectedLogType }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load from persistent storage
        if let savedLogs = loadFromDisk() {
            logs = savedLogs
        } else {
            // Create some sample logs for demonstration
            logs = createSampleLogs()
        }
    }
    
    func refreshLogs() async {
        await loadLogs()
    }
    
    func clearLogs() async {
        logs.removeAll()
        saveToDisk()
    }
    
    func addLog(level: LogLevel, type: LogType, message: String) {
        let entry = LogEntry(level: level, type: type, message: message)
        logs.append(entry)
        
        // Keep only the last N entries
        if logs.count > maxLogEntries {
            logs.removeFirst(logs.count - maxLogEntries)
        }
        
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func logsFilePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("PlayCoverManagerGUI")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("logs.json")
    }
    
    private func saveToDisk() {
        let filePath = logsFilePath()
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: filePath)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }
    
    private func loadFromDisk() -> [LogEntry]? {
        let filePath = logsFilePath()
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return try? JSONDecoder().decode([LogEntry].self, from: data)
    }
    
    private func createSampleLogs() -> [LogEntry] {
        [
            LogEntry(level: .info, type: .system, message: "PlayCover Manager GUI started"),
            LogEntry(level: .info, type: .application, message: "Loaded 3 applications"),
            LogEntry(level: .debug, type: .volume, message: "Scanning for APFS volumes..."),
            LogEntry(level: .info, type: .volume, message: "Found 2 PlayCover volumes"),
            LogEntry(level: .warning, type: .application, message: "App 'Genshin Impact' storage mode is external but volume is unmounted"),
        ]
    }
}

// MARK: - Global Logger

class Logger {
    static let shared = Logger()
    private var viewModel: LogViewerViewModel?
    
    func setViewModel(_ viewModel: LogViewerViewModel) {
        self.viewModel = viewModel
    }
    
    func log(_ level: LogLevel, type: LogType, message: String) {
        Task { @MainActor in
            viewModel?.addLog(level: level, type: type, message: message)
        }
        
        // Also print to console
        print("[\(level.displayName)] [\(type.displayName)] \(message)")
    }
    
    func debug(_ type: LogType, _ message: String) {
        log(.debug, type: type, message: message)
    }
    
    func info(_ type: LogType, _ message: String) {
        log(.info, type: type, message: message)
    }
    
    func warning(_ type: LogType, _ message: String) {
        log(.warning, type: type, message: message)
    }
    
    func error(_ type: LogType, _ message: String) {
        log(.error, type: type, message: message)
    }
}

#Preview {
    LogViewerView()
        .frame(width: 900, height: 600)
}
