//
//  ErrorManager.swift
//  PlayCoverManagerGUI
//
//  Unified error handling and presentation system
//

import Foundation
import SwiftUI
import AppKit

@MainActor
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: AppError?
    @Published var showingError = false
    
    private let logger = Logger.shared
    private let notificationManager = NotificationManager.shared
    
    private init() {}
    
    /// Present an error to the user
    func present(_ error: Error, context: ErrorContext = .general) {
        let appError: AppError
        
        // Convert to AppError if needed
        if let existing = error as? AppError {
            appError = existing
        } else {
            appError = AppError.from(error, context: context)
        }
        
        // Log the error
        logger.error(appError.logType, appError.message)
        
        // Show notification if enabled
        let settings = SettingsViewModel.shared
        if settings.notifyOnError {
            notificationManager.notifyError(message: appError.message)
        }
        
        // Present dialog
        currentError = appError
        showingError = true
    }
    
    /// Present an error with custom message
    func presentCustom(
        title: String,
        message: String,
        code: ErrorCode = .unknown,
        context: ErrorContext = .general,
        recoverySuggestions: [String] = []
    ) {
        let error = AppError(
            code: code,
            title: title,
            message: message,
            context: context,
            recoverySuggestions: recoverySuggestions
        )
        
        present(error, context: context)
    }
    
    /// Show an alert dialog
    func showAlert(for error: AppError) {
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.alertStyle = error.severity.alertStyle
        
        // Add recovery suggestions if available
        if !error.recoverySuggestions.isEmpty {
            let suggestions = error.recoverySuggestions.joined(separator: "\n• ")
            alert.informativeText += "\n\n対処方法:\n• \(suggestions)"
        }
        
        // Add buttons based on context
        alert.addButton(withTitle: "OK")
        
        if error.showHelpButton {
            alert.addButton(withTitle: "ヘルプ")
        }
        
        if error.showRetryButton {
            alert.addButton(withTitle: "再試行")
        }
        
        let response = alert.runModal()
        
        // Handle button response
        if response == .alertSecondResponse && error.showHelpButton {
            openHelp(for: error)
        }
    }
    
    /// Open help for specific error
    func openHelp(for error: AppError) {
        let helpURL: String
        
        switch error.context {
        case .volume:
            helpURL = "https://github.com/HEHEX8/PlayCoverManager/wiki/Volume-Management"
        case .installation:
            helpURL = "https://github.com/HEHEX8/PlayCoverManager/wiki/App-Installation"
        case .storage:
            helpURL = "https://github.com/HEHEX8/PlayCoverManager/wiki/Storage-Switching"
        case .authentication:
            helpURL = "https://github.com/HEHEX8/PlayCoverManager/wiki/Authentication"
        case .general:
            helpURL = "https://github.com/HEHEX8/PlayCoverManager/wiki"
        }
        
        if let url = URL(string: helpURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - App Error

struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let code: ErrorCode
    let title: String
    let message: String
    let context: ErrorContext
    let severity: ErrorSeverity
    let recoverySuggestions: [String]
    let showHelpButton: Bool
    let showRetryButton: Bool
    let logType: LogType
    
    init(
        code: ErrorCode,
        title: String,
        message: String,
        context: ErrorContext = .general,
        severity: ErrorSeverity = .error,
        recoverySuggestions: [String] = [],
        showHelpButton: Bool = true,
        showRetryButton: Bool = false
    ) {
        self.code = code
        self.title = title
        self.message = message
        self.context = context
        self.severity = severity
        self.recoverySuggestions = recoverySuggestions
        self.showHelpButton = showHelpButton
        self.showRetryButton = showRetryButton
        self.logType = context.logType
    }
    
    var errorDescription: String? {
        return message
    }
    
    /// Create AppError from any Error
    static func from(_ error: Error, context: ErrorContext) -> AppError {
        // Check if it's already an AppError
        if let appError = error as? AppError {
            return appError
        }
        
        // Check for specific error types
        if let privilegedError = error as? PrivilegedOperationError {
            return fromPrivilegedError(privilegedError, context: context)
        }
        
        if let shellError = error as? ShellError {
            return fromShellError(shellError, context: context)
        }
        
        // Generic error
        return AppError(
            code: .unknown,
            title: "\(context.displayName)エラー",
            message: error.localizedDescription,
            context: context,
            recoverySuggestions: [
                "アプリを再起動してみてください",
                "問題が解決しない場合は、GitHubでissueを作成してください"
            ]
        )
    }
    
    private static func fromPrivilegedError(_ error: PrivilegedOperationError, context: ErrorContext) -> AppError {
        switch error {
        case .authorizationFailed:
            return AppError(
                code: .authenticationFailed,
                title: "認証エラー",
                message: "管理者権限の取得に失敗しました",
                context: .authentication,
                recoverySuggestions: [
                    "正しいパスワードを入力してください",
                    "ユーザーアカウントに管理者権限があることを確認してください"
                ],
                showRetryButton: true
            )
            
        case .userCancelled:
            return AppError(
                code: .operationCancelled,
                title: "操作がキャンセルされました",
                message: "ユーザーによって操作がキャンセルされました",
                context: context,
                severity: .warning,
                showHelpButton: false
            )
            
        case .executionFailed(let message):
            return AppError(
                code: .executionError,
                title: "実行エラー",
                message: message,
                context: context,
                recoverySuggestions: [
                    "ディスクの空き容量を確認してください",
                    "アプリが実行中でないことを確認してください"
                ],
                showRetryButton: true
            )
            
        default:
            return AppError(
                code: .authenticationError,
                title: "認証エラー",
                message: error.localizedDescription,
                context: .authentication
            )
        }
    }
    
    private static func fromShellError(_ error: ShellError, context: ErrorContext) -> AppError {
        switch error {
        case .executionFailed(let code, let message):
            return AppError(
                code: .executionError,
                title: "コマンド実行エラー",
                message: "コマンドの実行に失敗しました (code: \(code)): \(message)",
                context: context,
                recoverySuggestions: [
                    "ディスクの状態を確認してください",
                    "ボリュームがマウントされているか確認してください"
                ],
                showRetryButton: true
            )
            
        case .scriptNotFound(let path):
            return AppError(
                code: .scriptNotFound,
                title: "スクリプトが見つかりません",
                message: "必要なスクリプトが見つかりません: \(path)",
                context: context,
                recoverySuggestions: [
                    "アプリを再インストールしてください"
                ]
            )
            
        case .parseError(let message):
            return AppError(
                code: .parseError,
                title: "データ解析エラー",
                message: message,
                context: context,
                recoverySuggestions: [
                    "データファイルが破損している可能性があります",
                    "アプリを再起動してください"
                ]
            )
            
        default:
            return AppError(
                code: .unknown,
                title: "エラー",
                message: error.localizedDescription,
                context: context
            )
        }
    }
}

// MARK: - Error Code

enum ErrorCode: String {
    case unknown = "UNKNOWN"
    case authenticationFailed = "AUTH_FAILED"
    case authenticationError = "AUTH_ERROR"
    case executionError = "EXEC_ERROR"
    case scriptNotFound = "SCRIPT_NOT_FOUND"
    case parseError = "PARSE_ERROR"
    case operationCancelled = "OPERATION_CANCELLED"
    case volumeNotFound = "VOLUME_NOT_FOUND"
    case insufficientSpace = "INSUFFICIENT_SPACE"
    case appRunning = "APP_RUNNING"
    case fileNotFound = "FILE_NOT_FOUND"
    case permissionDenied = "PERMISSION_DENIED"
}

// MARK: - Error Context

enum ErrorContext: String {
    case general = "general"
    case volume = "volume"
    case installation = "installation"
    case storage = "storage"
    case authentication = "authentication"
    
    var displayName: String {
        switch self {
        case .general: return "一般"
        case .volume: return "ボリューム"
        case .installation: return "インストール"
        case .storage: return "ストレージ"
        case .authentication: return "認証"
        }
    }
    
    var logType: LogType {
        switch self {
        case .general: return .system
        case .volume: return .volume
        case .installation: return .application
        case .storage: return .transfer
        case .authentication: return .system
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var alertStyle: NSAlert.Style {
        switch self {
        case .info: return .informational
        case .warning: return .warning
        case .error: return .warning
        case .critical: return .critical
        }
    }
}

// MARK: - Error View

struct ErrorAlertView: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(iconColor)
            
            // Title
            Text(error.title)
                .font(.title2)
                .fontWeight(.bold)
            
            // Message
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Recovery suggestions
            if !error.recoverySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("対処方法:")
                        .font(.headline)
                    
                    ForEach(error.recoverySuggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(suggestion)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Buttons
            HStack(spacing: 12) {
                if error.showHelpButton {
                    Button("ヘルプ") {
                        ErrorManager.shared.openHelp(for: error)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if let onRetry = onRetry, error.showRetryButton {
                    Button("再試行") {
                        onRetry()
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("OK") {
                    onDismiss()
                }
                .buttonStyle(error.showRetryButton ? .bordered : .borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 450)
    }
    
    private var iconName: String {
        switch error.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    private var iconColor: Color {
        switch error.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

#Preview {
    ErrorAlertView(
        error: AppError(
            code: .volumeNotFound,
            title: "ボリュームが見つかりません",
            message: "指定されたボリュームが見つかりませんでした。ボリュームが正しくマウントされているか確認してください。",
            context: .volume,
            recoverySuggestions: [
                "ボリュームリストを更新してください",
                "ボリュームを手動でマウントしてください"
            ],
            showRetryButton: true
        ),
        onDismiss: {},
        onRetry: {}
    )
}
