//
//  BatchConversionViewModel.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/27.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

struct FolderItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    var imageCount: Int
    var status: ConversionStatus = .pending
}

enum ConversionStatus: Equatable {
    case pending
    case processing
    case completed
    case failed(String)

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

@Observable
final class BatchConversionViewModel {
    var folders: [FolderItem] = []
    var outputDirectory: URL?
    var state: ProcessingState = .idle
    var currentProgress: Double = 0
    var currentFolder: String = ""
    var isDoublePage: Bool = false  // 是否為雙頁掃描模式

    private let epubService = EPubService.shared
    private let fileManager = FileManager.default

    @MainActor
    func selectSourceFolder() async {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.message = "選擇包含多個資料夾的主目錄"

        let response = await openPanel.begin()

        guard response == .OK, let url = openPanel.urls.first else {
            return
        }

        await scanFolders(in: url)
    }

    @MainActor
    func selectOutputDirectory() async {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.message = "選擇 ePub 輸出目錄"

        let response = await openPanel.begin()

        guard response == .OK, let url = openPanel.urls.first else {
            return
        }

        outputDirectory = url
    }

    private func scanFolders(in directory: URL) async {
        folders.removeAll()

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])

                guard resourceValues.isDirectory == true else { continue }

                // 掃描子資料夾中的圖片
                let images = findImages(in: item)

                if !images.isEmpty {
                    let folderItem = FolderItem(
                        url: item,
                        name: item.lastPathComponent,
                        imageCount: images.count
                    )
                    folders.append(folderItem)
                }
            }

            // 按名稱排序
            folders.sort { $0.name < $1.name }
        } catch {
            print("掃描資料夾失敗: \(error)")
        }
    }

    private func findImages(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var imageURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
                  resourceValues.isRegularFile == true,
                  let contentType = resourceValues.contentType else {
                continue
            }

            // 檢查是否為支持的圖片格式
            if contentType.conforms(to: .png) ||
               contentType.conforms(to: .jpeg) ||
               contentType.conforms(to: .webP) {
                imageURLs.append(fileURL)
            }
        }

        // 按文件名排序
        return imageURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @MainActor
    func startBatchConversion() async {
        guard !folders.isEmpty else { return }

        let output = outputDirectory ?? folders.first!.url.deletingLastPathComponent()

        state = .processing(progress: 0, message: "開始批次轉換...")

        let totalFolders = folders.count

        for (index, folder) in folders.enumerated() {
            currentFolder = folder.name
            folders[index].status = .processing

            do {
                // 獲取圖片列表
                let imageURLs = findImages(in: folder.url)

                guard !imageURLs.isEmpty else {
                    folders[index].status = .failed("無圖片")
                    continue
                }

                // 創建 ImageItem 列表
                let images = imageURLs.enumerated().map { idx, url in
                    ImageItem(url: url, order: idx)
                }

                // 創建 metadata（使用資料夾名稱作為書名）
                let metadata = EPubMetadata(
                    identifier: UUID().uuidString,
                    title: folder.name,
                    author: "NekoEPUB",
                    language: "zh",
                    date: ISO8601DateFormatter().string(from: Date()),
                    isDoublePage: isDoublePage
                )

                // 輸出 ePub 路徑
                let epubURL = output.appendingPathComponent("\(folder.name).epub")

                // 創建 ePub
                try await epubService.createEPub(
                    from: images,
                    metadata: metadata,
                    outputURL: epubURL
                )

                folders[index].status = .completed

            } catch {
                folders[index].status = .failed(error.localizedDescription)
            }

            // 更新總進度
            currentProgress = Double(index + 1) / Double(totalFolders)
            state = .processing(
                progress: currentProgress,
                message: "已完成 \(index + 1)/\(totalFolders)"
            )
        }

        state = .completed(outputURL: output)
    }

    func reset() {
        state = .idle
        currentProgress = 0
        currentFolder = ""
    }

    func clearFolders() {
        folders.removeAll()
        outputDirectory = nil
    }
}
