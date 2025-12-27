//
//  EPubToImagesView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct EPubToImagesView: View {
    @State private var viewModel = EPubToImagesViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "book.closed.fill")
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
                Text("ePub 轉圖片")
                    .font(.largeTitle.weight(.bold))

                Text("從 ePub 電子書中提取圖片為 PNG 格式")
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

            if let epubURL = viewModel.epubURL {
                VStack(spacing: 16) {
                    // File info card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("文件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(epubURL.lastPathComponent)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                            }

                            Spacer()
                        }

                        if let metadata = viewModel.metadata {
                            Divider()

                            VStack(spacing: 12) {
                                HStack {
                                    Label("標題", systemImage: "textformat")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(metadata.title)
                                        .font(.body)
                                        .lineLimit(1)

                                    Spacer()
                                }

                                HStack {
                                    Label("作者", systemImage: "person.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(metadata.author)
                                        .font(.body)
                                        .lineLimit(1)

                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                    )

                    Button {
                        Task {
                            await viewModel.extractImages()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("提取圖片")
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
                Text("已成功提取 \(viewModel.imageCount) 張圖片到：\n\(url.lastPathComponent)")
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
    EPubToImagesView()
}
