//
//  EPubService.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation
import ZIPFoundation

enum EPubError: LocalizedError {
    case invalidEPubStructure
    case imageConversionFailed
    case zipCreationFailed
    case insufficientPermissions
    case noImagesFound

    var errorDescription: String? {
        switch self {
        case .invalidEPubStructure:
            return "無效的 ePub 文件結構"
        case .imageConversionFailed:
            return "圖片轉換失敗"
        case .zipCreationFailed:
            return "創建 ePub 壓縮檔失敗"
        case .insufficientPermissions:
            return "文件權限不足"
        case .noImagesFound:
            return "未找到圖片"
        }
    }
}

final class EPubService {
    static let shared = EPubService()
    private let fileService = FileService.shared

    private init() {}

    // MARK: - Create ePub

    func createEPub(
        from images: [ImageItem],
        metadata: EPubMetadata,
        outputURL: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        let tempDir = try fileService.createTemporaryDirectory()
        defer { fileService.cleanupTemporaryDirectory(tempDir) }

        progressHandler?(0.1, "準備目錄結構...")

        // Create directory structure
        let metaInfDir = tempDir.appendingPathComponent("META-INF")
        let oebpsDir = tempDir.appendingPathComponent("OEBPS")
        let textDir = oebpsDir.appendingPathComponent("Text")
        let imagesDir = oebpsDir.appendingPathComponent("Images")

        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: textDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        progressHandler?(0.2, "寫入 mimetype...")

        // Write mimetype (must be first and uncompressed)
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        try EPubStructure.mimetype().write(to: mimetypeURL, atomically: true, encoding: .utf8)

        progressHandler?(0.3, "創建容器文件...")

        // Write container.xml
        let containerURL = metaInfDir.appendingPathComponent("container.xml")
        try EPubStructure.containerXML().write(to: containerURL, atomically: true, encoding: .utf8)

        // Process images
        let totalImages = images.count
        for (index, image) in images.enumerated() {
            let progress = 0.3 + (Double(index) / Double(totalImages)) * 0.4
            progressHandler?(progress, "處理圖片 \(index + 1)/\(totalImages)...")

            // 第一張圖片使用 "cover-image" 作為文件名
            let imageFileName: String
            if index == 0 {
                imageFileName = "cover-image.\(image.fileExtension)"
            } else {
                imageFileName = "image\(String(format: "%03d", index + 1)).\(image.fileExtension)"
            }

            let imageDestURL = imagesDir.appendingPathComponent(imageFileName)

            // Copy image
            try fileService.copyFile(from: image.url, to: imageDestURL)

            // Generate XHTML page
            let pageXHTML = EPubStructure.imagePageXHTML(
                imageFileName: imageFileName,
                pageNumber: index + 1,
                isDoublePage: metadata.isDoublePage
            )
            let pageURL = textDir.appendingPathComponent("page\(String(format: "%03d", index + 1)).xhtml")
            try pageXHTML.write(to: pageURL, atomically: true, encoding: .utf8)
        }

        progressHandler?(0.7, "生成內容目錄...")

        // Generate content.opf
        let contentOPF = EPubStructure.contentOPF(metadata: metadata, images: images)
        let contentOPFURL = oebpsDir.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentOPFURL, atomically: true, encoding: .utf8)

        // Generate toc.ncx
        let tocNCX = EPubStructure.tocNCX(metadata: metadata, pageCount: images.count)
        let tocNCXURL = oebpsDir.appendingPathComponent("toc.ncx")
        try tocNCX.write(to: tocNCXURL, atomically: true, encoding: .utf8)

        progressHandler?(0.8, "打包 ePub...")

        // Create ZIP archive
        try await createZIPArchive(from: tempDir, to: outputURL)

        progressHandler?(1.0, "完成")
    }

    private func createZIPArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        guard let archive = Archive(url: destinationURL, accessMode: .create) else {
            throw EPubError.zipCreationFailed
        }

        // Add mimetype first (uncompressed, as required by ePub spec)
        let mimetypeURL = sourceDir.appendingPathComponent("mimetype")
        try archive.addEntry(
            with: "mimetype",
            relativeTo: sourceDir,
            compressionMethod: .none
        )

        // Add all other files
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        guard let enumerator = enumerator else {
            throw EPubError.zipCreationFailed
        }

        for case let fileURL as URL in enumerator {
            // Skip mimetype (already added)
            if fileURL.lastPathComponent == "mimetype" {
                continue
            }

            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: sourceDir.path + "/",
                with: ""
            )

            try archive.addEntry(
                with: relativePath,
                relativeTo: sourceDir,
                compressionMethod: .deflate
            )
        }
    }

    // MARK: - Extract Images

    func extractImages(
        from epubURL: URL,
        to outputDirectory: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> [URL] {
        let tempDir = try fileService.createTemporaryDirectory()
        defer { fileService.cleanupTemporaryDirectory(tempDir) }

        progressHandler?(0.1, "解壓 ePub...")

        // Extract ePub
        try FileManager.default.unzipItem(at: epubURL, to: tempDir)

        progressHandler?(0.3, "解析內容...")

        // Find content.opf
        let contentOPFURL = try findContentOPF(in: tempDir)

        // Parse content.opf to find images
        let imageRelativePaths = try parseImagesFromOPF(at: contentOPFURL)

        guard !imageRelativePaths.isEmpty else {
            throw EPubError.noImagesFound
        }

        progressHandler?(0.5, "提取圖片...")

        // Create output directory
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        var extractedURLs: [URL] = []
        let oebpsDir = contentOPFURL.deletingLastPathComponent()

        for (index, relativePath) in imageRelativePaths.enumerated() {
            let progress = 0.5 + (Double(index) / Double(imageRelativePaths.count)) * 0.5
            progressHandler?(progress, "提取圖片 \(index + 1)/\(imageRelativePaths.count)...")

            let imageURL = oebpsDir.appendingPathComponent(relativePath)
            let outputFileName = "page\(String(format: "%03d", index + 1)).png"
            let outputURL = outputDirectory.appendingPathComponent(outputFileName)

            try fileService.copyFile(from: imageURL, to: outputURL)
            extractedURLs.append(outputURL)
        }

        progressHandler?(1.0, "完成")

        return extractedURLs
    }

    private func findContentOPF(in directory: URL) throws -> URL {
        // Parse META-INF/container.xml to find content.opf location
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")

        guard let containerData = try? Data(contentsOf: containerURL),
              let containerXML = try? XMLDocument(data: containerData),
              let rootfile = try? containerXML.nodes(forXPath: "//*[local-name()='rootfile']").first as? XMLElement,
              let fullPath = rootfile.attribute(forName: "full-path")?.stringValue else {
            // Fallback to default location
            return directory.appendingPathComponent("OEBPS/content.opf")
        }

        return directory.appendingPathComponent(fullPath)
    }

    private func parseImagesFromOPF(at opfURL: URL) throws -> [String] {
        let opfData = try Data(contentsOf: opfURL)
        let opfXML = try XMLDocument(data: opfData)

        // Use local-name() to avoid namespace issues
        let imageNodes = try opfXML.nodes(forXPath: "//*[local-name()='item'][starts-with(@media-type, 'image/')]")

        return imageNodes.compactMap { node -> String? in
            guard let element = node as? XMLElement,
                  let href = element.attribute(forName: "href")?.stringValue else {
                return nil
            }
            return href
        }
    }

    // MARK: - Parse Metadata

    func parseMetadata(from epubURL: URL) async throws -> EPubMetadata {
        let tempDir = try fileService.createTemporaryDirectory()
        defer { fileService.cleanupTemporaryDirectory(tempDir) }

        // Extract ePub
        try FileManager.default.unzipItem(at: epubURL, to: tempDir)

        // Find and parse content.opf
        let contentOPFURL = try findContentOPF(in: tempDir)
        let opfData = try Data(contentsOf: contentOPFURL)
        let opfXML = try XMLDocument(data: opfData)

        // Use local-name() to avoid namespace issues
        let identifier = try opfXML.nodes(forXPath: "//*[local-name()='identifier']").first?.stringValue ?? ""
        let title = try opfXML.nodes(forXPath: "//*[local-name()='title']").first?.stringValue ?? "Unknown"
        let author = try opfXML.nodes(forXPath: "//*[local-name()='creator']").first?.stringValue ?? "Unknown"
        let language = try opfXML.nodes(forXPath: "//*[local-name()='language']").first?.stringValue ?? "en"
        let date = try opfXML.nodes(forXPath: "//*[local-name()='meta'][@property='dcterms:modified']").first?.stringValue ?? ""

        return EPubMetadata(
            identifier: identifier,
            title: title,
            author: author,
            language: language,
            date: date
        )
    }
}
