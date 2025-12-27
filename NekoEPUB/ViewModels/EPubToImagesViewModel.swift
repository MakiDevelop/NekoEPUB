//
//  EPubToImagesViewModel.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
final class EPubToImagesViewModel {
    var epubURL: URL?
    var imageCount: Int = 0
    var metadata: EPubMetadata?
    var state: ProcessingState = .idle

    private let epubService = EPubService.shared

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

        // Parse metadata
        do {
            metadata = try await epubService.parseMetadata(from: url)
            // TODO: Count images
            imageCount = 0
        } catch {
            state = .error(message: "無法解析 ePub: \(error.localizedDescription)")
        }
    }

    @MainActor
    func extractImages() async {
        guard let epubURL = epubURL else { return }

        state = .processing(progress: 0, message: "準備提取圖片...")

        // Show folder selection panel
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.prompt = "選擇輸出目錄"

        let response = await openPanel.begin()

        guard response == .OK, let outputDirectory = openPanel.urls.first else {
            state = .idle
            return
        }

        do {
            let extractedURLs = try await epubService.extractImages(
                from: epubURL,
                to: outputDirectory
            ) { progress, message in
                Task { @MainActor in
                    self.state = .processing(progress: progress, message: message)
                }
            }

            await MainActor.run {
                imageCount = extractedURLs.count
                state = .completed(outputURL: outputDirectory)
            }
        } catch {
            await MainActor.run {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
        epubURL = nil
        metadata = nil
        imageCount = 0
    }
}
