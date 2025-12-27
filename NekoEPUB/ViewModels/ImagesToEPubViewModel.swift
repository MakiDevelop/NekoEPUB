//
//  ImagesToEPubViewModel.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
final class ImagesToEPubViewModel {
    var images: [ImageItem] = []
    var state: ProcessingState = .idle

    private let epubService = EPubService.shared

    func addImages(urls: [URL]) {
        let newImages = urls.enumerated().map { index, url in
            ImageItem(url: url, order: images.count + index)
        }
        images.append(contentsOf: newImages)
    }

    func removeImage(at indexSet: IndexSet) {
        images.remove(atOffsets: indexSet)

        // Update order
        for (index, _) in images.enumerated() {
            images[index].order = index
        }
    }

    func moveImages(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)

        // Update order
        for (index, _) in images.enumerated() {
            images[index].order = index
        }
    }

    @MainActor
    func createEPub() async {
        guard !images.isEmpty else { return }

        state = .processing(progress: 0, message: "準備創建 ePub...")

        // Show save panel (must be on main thread)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.epub]
        savePanel.nameFieldStringValue = "PhotoAlbum.epub"

        let response = await savePanel.begin()

        guard response == .OK, let outputURL = savePanel.url else {
            state = .idle
            return
        }

        do {
            let metadata = EPubMetadata.default

            try await epubService.createEPub(
                from: images,
                metadata: metadata,
                outputURL: outputURL
            ) { progress, message in
                Task { @MainActor in
                    self.state = .processing(progress: progress, message: message)
                }
            }

            await MainActor.run {
                state = .completed(outputURL: outputURL)
            }
        } catch {
            await MainActor.run {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
    }
}
