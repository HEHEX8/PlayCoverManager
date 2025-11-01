//
//  SetupWizardView.swift
//  PlayCoverManagerGUI
//
//  Initial setup wizard for first-time users
//

import SwiftUI

struct SetupWizardView: View {
    @StateObject private var viewModel = SetupWizardViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
            
            Divider()
            
            // Content
            TabView(selection: $viewModel.currentStep) {
                WelcomeStepView()
                    .tag(SetupStep.welcome)
                
                ExternalDriveSelectionView(viewModel: viewModel)
                    .tag(SetupStep.driveSelection)
                
                VolumeCreationView(viewModel: viewModel)
                    .tag(SetupStep.volumeCreation)
                
                CompletionStepView(onComplete: {
                    Task {
                        await appState.completeSetup()
                    }
                })
                    .tag(SetupStep.completion)
            }
            .tabViewStyle(.automatic)
            
            Divider()
            
            // Navigation buttons
            navigationButtons
        }
        .frame(width: 700, height: 550)
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(SetupStep.allCases, id: \.self) { step in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(stepColor(step))
                            .frame(width: 32, height: 32)
                        
                        if viewModel.currentStep.rawValue > step.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        } else {
                            Text("\(step.rawValue + 1)")
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        }
                    }
                    
                    if step != SetupStep.allCases.last {
                        Rectangle()
                            .fill(stepColor(step))
                            .frame(width: 60, height: 2)
                    }
                }
            }
        }
        .padding()
    }
    
    private func stepColor(_ step: SetupStep) -> Color {
        if viewModel.currentStep.rawValue >= step.rawValue {
            return .accentColor
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if viewModel.currentStep != .welcome {
                Button("戻る") {
                    viewModel.previousStep()
                }
                .keyboardShortcut(.cancelAction)
            }
            
            Spacer()
            
            if viewModel.currentStep != .completion {
                Button(viewModel.currentStep == .volumeCreation ? "作成" : "次へ") {
                    Task {
                        await viewModel.nextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

// MARK: - Setup Steps
enum SetupStep: Int, CaseIterable {
    case welcome = 0
    case driveSelection = 1
    case volumeCreation = 2
    case completion = 3
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 12) {
                Text("PlayCover Manager へようこそ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("外部ストレージを使ってiOSアプリを管理します")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "externaldrive.fill", text: "外部ストレージにアプリデータを保存", color: .blue)
                FeatureRow(icon: "internaldrive.fill", text: "内蔵ストレージの容量を節約", color: .purple)
                FeatureRow(icon: "arrow.left.arrow.right.circle.fill", text: "内蔵⇄外部の切り替えが簡単", color: .green)
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - External Drive Selection
struct ExternalDriveSelectionView: View {
    @ObservedObject var viewModel: SetupWizardViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("外部ドライブを選択")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("PlayCoverのデータを保存する外部ドライブを選択してください")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if viewModel.isScanning {
                ProgressView("ドライブをスキャン中...")
            } else if viewModel.availableDrives.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.xmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("外部ドライブが見つかりません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("再スキャン") {
                        Task {
                            await viewModel.scanDrives()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.availableDrives, id: \.identifier) { drive in
                            DriveSelectionCard(
                                drive: drive,
                                isSelected: viewModel.selectedDrive?.identifier == drive.identifier,
                                onSelect: {
                                    viewModel.selectedDrive = drive
                                }
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            await viewModel.scanDrives()
        }
    }
}

struct DriveSelectionCard: View {
    let drive: ExternalDrive
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: "externaldrive.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.headline)
                    
                    Text("\(drive.capacity) (\(drive.available) 空き)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(drive.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Volume Creation
struct VolumeCreationView: View {
    @ObservedObject var viewModel: SetupWizardViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            if viewModel.isCreatingVolume {
                // Creating volume
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("ボリュームを作成中...")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let selectedDrive = viewModel.selectedDrive {
                        Text(selectedDrive.name)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Configuration
                VStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("ボリュームの設定")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("PlayCover用のボリュームを作成します")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    if let drive = viewModel.selectedDrive {
                        InfoRow(label: "ドライブ", value: drive.name)
                        InfoRow(label: "空き容量", value: drive.available)
                    }
                    
                    HStack {
                        Text("ボリュームサイズ")
                            .font(.subheadline)
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $viewModel.volumeSize, in: 10...500, step: 10)
                        
                        Text("\(Int(viewModel.volumeSize)) GB")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Completion Step
struct CompletionStepView: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("セットアップ完了！")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("PlayCover Managerを使い始めることができます")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("始める") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SetupWizardView()
}
