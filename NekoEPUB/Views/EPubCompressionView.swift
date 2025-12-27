//
//  EPubCompressionView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct EPubCompressionView: View {
    @State private var viewModel = EPubCompressionViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "archivebox.fill")
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
                Text("壓縮 ePub")
                    .font(.largeTitle.weight(.bold))

                Text("通過壓縮圖片質量來減小 ePub 文件體積")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.selectEPub()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                    Text("選擇 ePub 文件")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if viewModel.epubURL != nil {
                VStack(spacing: 16) {
                    // Settings card
                    VStack(alignment: .leading, spacing: 20) {
                        // Quality slider
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("圖片質量", systemImage: "slider.horizontal.3")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Text("\(viewModel.settings.qualityPercentage)%")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }

                            Slider(value: $viewModel.settings.quality, in: 0.1...1.0, step: 0.05)
                                .tint(.accentColor)
                                .onChange(of: viewModel.settings.quality) { _, _ in
                                    viewModel.updateEstimate()
                                }

                            HStack {
                                Text("低質量")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("高質量")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        // Format picker
                        VStack(alignment: .leading, spacing: 12) {
                            Label("輸出格式", systemImage: "photo")
                                .font(.body.weight(.semibold))

                            Picker("格式", selection: $viewModel.settings.format) {
                                ForEach(CompressionFormat.allCases) { format in
                                    Text(format.rawValue.uppercased()).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: viewModel.settings.format) { _, _ in
                                viewModel.updateEstimate()
                            }
                        }

                        Divider()

                        // Size comparison
                        HStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 4) {
                                    Text("原始大小")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(FileService.shared.formatFileSize(viewModel.originalSize))
                                        .font(.body.weight(.bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)

                            VStack(spacing: 8) {
                                Image(systemName: "doc.badge.arrow.up.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)

                                VStack(spacing: 4) {
                                    Text("預估大小")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(FileService.shared.formatFileSize(viewModel.estimatedSize))
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 550)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                    )

                    Button {
                        Task {
                            await viewModel.compress()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("壓縮並保存")
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

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewModel.state.isProcessing {
                progressOverlay
            }
        }
        .alert("成功", isPresented: .constant(viewModel.state.isCompleted)) {
            Button("確定") {
                viewModel.reset()
            }
        } message: {
            if let url = viewModel.state.outputURL {
                Text("ePub 已成功壓縮：\n\(url.lastPathComponent)")
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

#Preview {
    EPubCompressionView()
}
