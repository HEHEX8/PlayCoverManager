//
//  PlayCoverManagerGUIApp.swift
//  PlayCoverManagerGUI
//
//  Created by PlayCover Manager Team
//

import SwiftUI

@main
struct PlayCoverManagerGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove "New Window" menu item
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
