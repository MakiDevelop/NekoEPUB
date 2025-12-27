//
//  ImageReorderList.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import AppKit

struct ImageReorderList: View {
    @Binding var images: [ImageItem]
    let onDelete: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("圖片順序", systemImage: "list.number")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(images.count) 張")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .padding(.horizontal)

            if images.isEmpty {
                emptyState
            } else {
                imageList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("尚未添加圖片")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("從上方拖入或選擇圖片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    private var imageList: some View {
        List {
            ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                ImageRow(image: image, index: index)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                moveImages(from: from, to: to)
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(minHeight: 300)
    }

    private func moveImages(from source: IndexSet, to destination: Int) {
        var updatedImages = images
        updatedImages.move(fromOffsets: source, toOffset: destination)

        // Update order after moving
        for (index, _) in updatedImages.enumerated() {
            updatedImages[index].order = index
        }

        images = updatedImages
    }
}

struct ImageRow: View {
    let image: ImageItem
    let index: Int

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Index badge
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                Text("\(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            ProgressView()
                                .controlSize(.small)
                        )
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 6) {
                Text(image.filename)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(image.fileExtension.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(formatColor(for: image.fileExtension))
                        )
                }
            }

            Spacer()

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary.opacity(isHovered ? 1 : 0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: 2)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            loadThumbnail()
        }
    }

    private func formatColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "png": return .blue
        case "jpg", "jpeg": return .orange
        case "webp": return .purple
        default: return .gray
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let loadedImage = NSImage(contentsOf: image.url) else { return }

            // Create thumbnail
            let targetSize = CGSize(width: 50, height: 50)
            let thumbImage = NSImage(size: targetSize)

            thumbImage.lockFocus()
            loadedImage.draw(in: NSRect(origin: .zero, size: targetSize),
                           from: NSRect(origin: .zero, size: loadedImage.size),
                           operation: .copy,
                           fraction: 1.0)
            thumbImage.unlockFocus()

            DispatchQueue.main.async {
                self.thumbnail = thumbImage
            }
        }
    }
}

#Preview {
    @Previewable @State var images: [ImageItem] = [
        ImageItem(url: URL(fileURLWithPath: "/tmp/image1.png"), order: 0),
        ImageItem(url: URL(fileURLWithPath: "/tmp/image2.jpg"), order: 1),
        ImageItem(url: URL(fileURLWithPath: "/tmp/image3.webp"), order: 2)
    ]

    ImageReorderList(images: $images) { indexSet in
        images.remove(atOffsets: indexSet)
    }
    .frame(width: 400, height: 500)
}
