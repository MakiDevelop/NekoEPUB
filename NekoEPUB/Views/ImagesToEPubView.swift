//
//  ImagesToEPubView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImagesToEPubView: View {
    @State private var viewModel = ImagesToEPubViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Label("圖片轉 ePub", systemImage: "photo.stack")
                        .font(.title2.weight(.bold))

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Divider()
                    .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 24) {
                    DropZoneView(
                        title: "拖放圖片到這裡（PNG、JPEG、WebP）",
                        supportedTypes: [.png, .jpeg, .webP]
                    ) { urls in
                        viewModel.addImages(urls: urls)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    ImageReorderList(images: $viewModel.images) { indexSet in
                        viewModel.removeImage(at: indexSet)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 100)
            }

            Divider()

            bottomBar
        }
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
                Text("ePub 已成功創建：\n\(url.lastPathComponent)")
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

    private var bottomBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill")
                    .foregroundStyle(.secondary)
                Text("\(viewModel.images.count) 張圖片")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.1))
            )

            // 雙頁掃描模式開關
            Toggle(isOn: $viewModel.isDoublePage) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.split.2x1")
                    Text("雙頁掃描")
                }
                .font(.body.weight(.medium))
            }
            .toggleStyle(.switch)
            .disabled(viewModel.state.isProcessing)

            // 清除按鈕
            if !viewModel.images.isEmpty {
                Button {
                    viewModel.clearAllImages()
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
            }

            Spacer()

            Button {
                Task {
                    await viewModel.createEPub()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                    Text("創建 ePub")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .disabled(viewModel.images.isEmpty || viewModel.state.isProcessing)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
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
    ImagesToEPubView()
}
