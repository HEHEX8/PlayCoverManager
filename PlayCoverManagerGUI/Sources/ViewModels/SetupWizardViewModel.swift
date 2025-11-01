//
//  SetupWizardViewModel.swift
//  PlayCoverManagerGUI
//
//  ViewModel for setup wizard
//

import Foundation
import SwiftUI

struct ExternalDrive: Identifiable {
    let id = UUID()
    let identifier: String  // diskX
    let name: String
    let path: String
    let capacity: String
    let available: String
}

@MainActor
class SetupWizardViewModel: ObservableObject {
    @Published var currentStep: SetupStep = .welcome
    @Published var availableDrives: [ExternalDrive] = []
    @Published var selectedDrive: ExternalDrive?
    @Published var volumeSize: Double = 100.0
    @Published var isScanning = false
    @Published var isCreatingVolume = false
    @Published var errorMessage: String?
    
    private let shellExecutor = ShellScriptExecutor.shared
    
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .driveSelection:
            return selectedDrive != nil
        case .volumeCreation:
            return !isCreatingVolume
        case .completion:
            return true
        }
    }
    
    func nextStep() async {
        switch currentStep {
        case .welcome:
            currentStep = .driveSelection
            
        case .driveSelection:
            currentStep = .volumeCreation
            
        case .volumeCreation:
            await createVolume()
            
        case .completion:
            break
        }
    }
    
    func previousStep() {
        guard let current = SetupStep.allCases.firstIndex(of: currentStep),
              current > 0 else { return }
        currentStep = SetupStep.allCases[current - 1]
    }
    
    func scanDrives() async {
        isScanning = true
        defer { isScanning = false }
        
        do {
            // Get list of external drives
            let output = try await shellExecutor.executeCommand(
                "diskutil list external | grep '/dev/disk' | awk '{print $1}'"
            )
            
            let diskIdentifiers = output.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            var drives: [ExternalDrive] = []
            
            for identifier in diskIdentifiers {
                // Get drive info
                let infoOutput = try await shellExecutor.executeCommand(
                    "diskutil info \(identifier)"
                )
                
                // Parse drive info
                let lines = infoOutput.components(separatedBy: .newlines)
                var name = identifier
                var path = "/Volumes/Unknown"
                var capacity = "Unknown"
                var available = "Unknown"
                
                for line in lines {
                    if line.contains("Volume Name:") {
                        name = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? name
                    } else if line.contains("Mount Point:") {
                        path = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? path
                    } else if line.contains("Volume Total Space:") {
                        capacity = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? capacity
                    } else if line.contains("Volume Free Space:") {
                        available = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? available
                    }
                }
                
                // Only add if it's a valid external drive
                if !path.isEmpty && path != "/Volumes/Unknown" {
                    let drive = ExternalDrive(
                        identifier: identifier,
                        name: name,
                        path: path,
                        capacity: capacity,
                        available: available
                    )
                    drives.append(drive)
                }
            }
            
            availableDrives = drives
            
        } catch {
            errorMessage = "ドライブのスキャンに失敗: \(error.localizedDescription)"
        }
    }
    
    func createVolume() async {
        guard let drive = selectedDrive else { return }
        
        isCreatingVolume = true
        defer { isCreatingVolume = false }
        
        do {
            // Create APFS volume
            let volumeName = "PlayCover"
            let sizeGB = Int(volumeSize)
            
            _ = try await shellExecutor.executeCommand(
                "sudo diskutil apfs addVolume \(drive.identifier) APFS '\(volumeName)' -size \(sizeGB)g"
            )
            
            // Wait a bit for volume to be ready
            try await Task.sleep(for: .seconds(2))
            
            // Mount the volume
            let mountPath = AppConstants.playCoverContainer.path
            try await shellExecutor.mountVolume(volumeName: volumeName, mountPath: mountPath)
            
            // Create data directory
            try await shellExecutor.executeCommand(
                "mkdir -p '\(AppConstants.dataDirectory.path)'"
            )
            
            // Create empty mapping file
            try await shellExecutor.executeCommand(
                "touch '\(AppConstants.mappingFile.path)'"
            )
            
            // Success - move to completion
            currentStep = .completion
            
        } catch {
            errorMessage = "ボリュームの作成に失敗: \(error.localizedDescription)"
        }
    }
}
