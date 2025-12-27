//
//  DropZoneView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let title: String
    let supportedTypes: [UTType]
    let onFilesDropped: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    .symbolEffect(.bounce, value: isTargeted)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)

                Text("或")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                selectFiles()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("選擇文件")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.accentColor.gradient)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                defer { group.leave() }

                if let url = url, supportedTypes.contains(where: { $0.conforms(to: url.utType) }) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                onFilesDropped(urls)
            }
        }

        return true
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = supportedTypes

        panel.begin { response in
            if response == .OK {
                onFilesDropped(panel.urls)
            }
        }
    }
}

extension URL {
    var utType: UTType {
        (try? resourceValues(forKeys: [.contentTypeKey]).contentType) ?? .data
    }
}

#Preview {
    DropZoneView(
        title: "拖放圖片到這裡",
        supportedTypes: [.png, .jpeg, .webP]
    ) { urls in
        print("Files dropped: \(urls)")
    }
    .padding()
}
