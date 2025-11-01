//
//  SetupWizardViewModel.swift
//  PlayCoverManagerGUI
//
//  ViewModel for setup wizard
//

import Foundation
import SwiftUI

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
    private let privilegedOps = PrivilegedOperationManager.shared
    
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
            // Create APFS volume with sudo privileges
            let volumeName = "PlayCover"
            let sizeGB = Int(volumeSize)
            let size = "\(sizeGB)g"
            
            try await privilegedOps.createAPFSVolume(
                containerDisk: drive.identifier,
                volumeName: volumeName,
                size: size
            )
            
            // Wait a bit for volume to be ready
            try await Task.sleep(for: .seconds(2))
            
            // Mount the volume with sudo privileges
            let mountPath = AppConstants.playCoverContainer.path
            try await privilegedOps.mountVolume(volumeName: volumeName, mountPath: mountPath)
            
            // Create data directory (may need sudo)
            try await privilegedOps.executeSudoCommand(
                "mkdir",
                arguments: ["-p", AppConstants.dataDirectory.path]
            )
            
            // Create empty mapping file
            try await privilegedOps.executeSudoCommand(
                "touch",
                arguments: [AppConstants.mappingFile.path]
            )
            
            // Set proper permissions
            let currentUser = NSUserName()
            let currentGroup = "staff"  // Default group on macOS
            try await privilegedOps.changeOwnership(
                path: mountPath,
                owner: currentUser,
                group: currentGroup
            )
            
            // Success - move to completion
            currentStep = .completion
            
        } catch {
            errorMessage = "ボリュームの作成に失敗: \(error.localizedDescription)"
        }
    }
}
