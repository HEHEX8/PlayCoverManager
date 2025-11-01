//
//  NotificationManager.swift
//  PlayCoverManagerGUI
//
//  Manages macOS notifications
//

import Foundation
import UserNotifications

@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    /// Request notification permission
    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            } else if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
    }
    
    /// Send a notification
    func send(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        sound: UNNotificationSound = .default
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    /// Notification convenience methods
    
    func notifyInstallComplete(appName: String) {
        send(
            title: "インストール完了",
            body: "\(appName) のインストールが完了しました"
        )
    }
    
    func notifyUninstallComplete(appName: String) {
        send(
            title: "アンインストール完了",
            body: "\(appName) のアンインストールが完了しました"
        )
    }
    
    func notifyStorageSwitchComplete(appName: String, toExternal: Bool) {
        let location = toExternal ? "外部ストレージ" : "内蔵ストレージ"
        send(
            title: "ストレージ切替完了",
            body: "\(appName) を\(location)に移動しました"
        )
    }
    
    func notifyVolumeOperation(operation: String, volumeName: String) {
        send(
            title: "ボリューム操作完了",
            body: "\(volumeName) の\(operation)が完了しました"
        )
    }
    
    func notifyError(message: String) {
        send(
            title: "エラー",
            body: message,
            sound: .defaultCritical
        )
    }
    
    func notifyMaintenanceComplete(operation: String) {
        send(
            title: "メンテナンス完了",
            body: "\(operation)が完了しました"
        )
    }
}
