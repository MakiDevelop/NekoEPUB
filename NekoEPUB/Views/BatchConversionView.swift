//
//  BatchConversionView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/27.
//

import SwiftUI

struct BatchConversionView: View {
    @State private var viewModel = BatchConversionViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("批次轉檔")
                    .font(.largeTitle.weight(.bold))

                Text("選擇包含多個子資料夾的目錄，批次轉換為 ePub")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 選擇資料夾按鈕
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.selectSourceFolder()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                            Text("選擇來源目錄")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !viewModel.folders.isEmpty {
                        Button {
                            Task {
                                await viewModel.selectOutputDirectory()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.outputDirectory != nil ? "checkmark.circle.fill" : "folder")
                                Text(viewModel.outputDirectory != nil ? "已選擇輸出目錄" : "選擇輸出目錄")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                // 雙頁掃描模式開關
                if !viewModel.folders.isEmpty {
                    Toggle(isOn: $viewModel.isDoublePage) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.split.2x1")
                            Text("雙頁掃描模式")
                                .font(.body.weight(.medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal, 24)
                    .disabled(viewModel.state.isProcessing)
                }
            }

            // 資料夾列表
            if !viewModel.folders.isEmpty {
                VStack(spacing: 16) {
                    // 統計卡片
                    HStack(spacing: 20) {
                        StatCard(
                            icon: "folder.fill",
                            label: "資料夾",
                            value: "\(viewModel.folders.count)",
                            color: .blue
                        )

                        StatCard(
                            icon: "photo.fill",
                            label: "總圖片",
                            value: "\(viewModel.folders.reduce(0) { $0 + $1.imageCount })",
                            color: .orange
                        )

                        StatCard(
                            icon: "checkmark.circle.fill",
                            label: "已完成",
                            value: "\(viewModel.folders.filter { if case .completed = $0.status { return true }; return false }.count)",
                            color: .green
                        )
                    }
                    .padding(.horizontal)

                    // 資料夾列表
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.folders) { folder in
                                FolderRow(folder: folder)
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    .padding(.horizontal)

                    // 操作按鈕
                    HStack(spacing: 12) {
                        Button {
                            viewModel.clearFolders()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("清空")
                            }
                            .font(.body.weight(.medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                        )
                        .disabled(viewModel.state.isProcessing)

                        Button {
                            Task {
                                await viewModel.startBatchConversion()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.circle.fill")
                                Text("開始批次轉換")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.state.isProcessing)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewModel.state.isProcessing {
                progressOverlay
            }
        }
        .alert("完成", isPresented: .constant(viewModel.state.isCompleted)) {
            Button("確定") {
                viewModel.reset()
            }
        } message: {
            if let url = viewModel.state.outputURL {
                Text("批次轉換完成！\nePub 文件已保存到：\(url.path)")
            }
        }
        .alert("錯誤", isPresented: .constant(viewModel.state.isError)) {
            Button("確定") {
                viewModel.reset()
            }
        } message: {
            if let error = viewModel.state.errorMessage {
                Text(error)
            }
        }
    }

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if case .processing(let progress, let message) = viewModel.state {
                    VStack(spacing: 20) {
                        ProgressView(value: progress) {
                            VStack(spacing: 12) {
                                Text(message)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if !viewModel.currentFolder.isEmpty {
                                    Text("正在處理: \(viewModel.currentFolder)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 320)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
                    )
                }
            }
        }
    }
}

struct FolderRow: View {
    let folder: FolderItem

    var body: some View {
        HStack(spacing: 12) {
            // 狀態圖標
            Image(systemName: folder.status.icon)
                .font(.title3)
                .foregroundStyle(folder.status.color)
                .frame(width: 24)
                .symbolEffect(.pulse, value: folder.status)

            // 資料夾資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.body.weight(.medium))

                Text("\(folder.imageCount) 張圖片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 狀態文字
            if case .failed(let error) = folder.status {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    BatchConversionView()
}
