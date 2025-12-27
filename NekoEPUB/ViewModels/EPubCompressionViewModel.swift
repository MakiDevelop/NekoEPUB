//
//  EPubCompressionViewModel.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
final class EPubCompressionViewModel {
    var epubURL: URL?
    var settings = CompressionSettings()
    var originalSize: Int64 = 0
    var estimatedSize: Int64 = 0
    var state: ProcessingState = .idle

    private let imageService = ImageProcessingService.shared
    private let fileService = FileService.shared

    @MainActor
    func selectEPub() async {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.epub]

        let response = await openPanel.begin()

        guard response == .OK, let url = openPanel.urls.first else {
            return
        }

        epubURL = url

        // Get file size
        do {
            originalSize = try fileService.getFileSize(at: url)
            updateEstimate()
        } catch {
            state = .error(message: "無法讀取文件: \(error.localizedDescription)")
        }
    }

    func updateEstimate() {
        estimatedSize = imageService.estimateCompressedSize(
            originalSize: originalSize,
            quality: settings.quality,
            format: settings.format
        )
    }

    @MainActor
    func compress() async {
        guard let epubURL = epubURL else { return }

        state = .processing(progress: 0, message: "準備壓縮...")

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.epub]
        savePanel.nameFieldStringValue = epubURL.deletingPathExtension().lastPathComponent + "_compressed.epub"

        let response = await savePanel.begin()

        guard response == .OK, let outputURL = savePanel.url else {
            state = .idle
            return
        }

        do {
            try await imageService.compressEPub(
                at: epubURL,
                settings: settings,
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
