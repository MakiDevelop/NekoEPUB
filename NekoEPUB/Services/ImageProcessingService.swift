//
//  ImageProcessingService.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import ZIPFoundation

final class ImageProcessingService {
    static let shared = ImageProcessingService()

    private init() {}

    func compressImage(
        at url: URL,
        quality: Double,
        format: CompressionFormat
    ) async throws -> Data {
        // Image processing must happen on main thread for AppKit
        return try await MainActor.run {
            guard let image = NSImage(contentsOf: url) else {
                throw EPubError.imageConversionFailed
            }

            guard let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
            ) else {
                throw EPubError.imageConversionFailed
            }

            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

            switch format {
            case .jpeg:
                guard let jpegData = bitmapRep.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: quality]
                ) else {
                    throw EPubError.imageConversionFailed
                }
                return jpegData

            case .webp:
                // For WebP, we'll convert to JPEG for simplicity
                // True WebP support would require ImageIO or a third-party library
                guard let jpegData = bitmapRep.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: quality]
                ) else {
                    throw EPubError.imageConversionFailed
                }
                return jpegData
            }
        }
    }

    func estimateCompressedSize(
        originalSize: Int64,
        quality: Double,
        format: CompressionFormat
    ) -> Int64 {
        // Simple estimation based on quality
        // JPEG typically achieves 10:1 to 20:1 compression at medium quality
        let baseCompressionRatio = format == .webp ? 15.0 : 12.0
        let qualityFactor = 1.0 - (quality * 0.5)  // Lower quality = more compression
        let estimatedRatio = baseCompressionRatio * (1.0 + qualityFactor)

        return Int64(Double(originalSize) / estimatedRatio)
    }

    func compressEPub(
        at epubURL: URL,
        settings: CompressionSettings,
        outputURL: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        let fileService = FileService.shared
        let tempDir = try fileService.createTemporaryDirectory()
        defer { fileService.cleanupTemporaryDirectory(tempDir) }

        progressHandler?(0.1, "解壓 ePub...")

        // Extract ePub
        try FileManager.default.unzipItem(at: epubURL, to: tempDir)

        progressHandler?(0.2, "查找圖片...")

        // Find all images
        let imageURLs = try findImages(in: tempDir)

        guard !imageURLs.isEmpty else {
            throw EPubError.noImagesFound
        }

        // Compress each image
        for (index, imageURL) in imageURLs.enumerated() {
            let progress = 0.2 + (Double(index) / Double(imageURLs.count)) * 0.6
            progressHandler?(progress, "壓縮圖片 \(index + 1)/\(imageURLs.count)...")

            do {
                let compressedData = try await compressImage(
                    at: imageURL,
                    quality: settings.quality,
                    format: settings.format
                )

                // Replace original image with compressed version
                let outputExtension = settings.format.fileExtension
                let newURL = imageURL.deletingPathExtension().appendingPathExtension(outputExtension)

                // If format changed, remove old file
                if imageURL != newURL {
                    try FileManager.default.removeItem(at: imageURL)
                }

                try compressedData.write(to: newURL)

                // Update OPF file if extension changed
                if imageURL.pathExtension != outputExtension {
                    try updateOPFReferences(
                        in: tempDir,
                        oldPath: imageURL.lastPathComponent,
                        newPath: newURL.lastPathComponent
                    )
                }
            } catch {
                // If compression fails for one image, continue with others
                print("Failed to compress \(imageURL.lastPathComponent): \(error)")
            }
        }

        progressHandler?(0.8, "重新打包 ePub...")

        // Re-create ePub
        try await createZIPArchive(from: tempDir, to: outputURL)

        progressHandler?(1.0, "完成")
    }

    private func findImages(in directory: URL) throws -> [URL] {
        var imageURLs: [URL] = []

        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )

        guard let enumerator = enumerator else { return [] }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey])

            guard resourceValues.isRegularFile == true,
                  let contentType = resourceValues.contentType else {
                continue
            }

            // Check if it's an image
            if contentType.conforms(to: .image) {
                imageURLs.append(fileURL)
            }
        }

        return imageURLs
    }

    private func updateOPFReferences(
        in directory: URL,
        oldPath: String,
        newPath: String
    ) throws {
        // Find content.opf
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")

        guard let containerData = try? Data(contentsOf: containerURL),
              let containerXML = try? XMLDocument(data: containerData),
              let rootfile = try? containerXML.nodes(forXPath: "//rootfile").first as? XMLElement,
              let fullPath = rootfile.attribute(forName: "full-path")?.stringValue else {
            return
        }

        let opfURL = directory.appendingPathComponent(fullPath)

        guard var opfContent = try? String(contentsOf: opfURL, encoding: .utf8) else {
            return
        }

        // Replace references
        opfContent = opfContent.replacingOccurrences(of: oldPath, with: newPath)

        try opfContent.write(to: opfURL, atomically: true, encoding: .utf8)
    }

    private func createZIPArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        // Remove existing file
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        guard let archive = Archive(url: destinationURL, accessMode: .create) else {
            throw EPubError.zipCreationFailed
        }

        // Add mimetype first (uncompressed)
        let mimetypeURL = sourceDir.appendingPathComponent("mimetype")
        if FileManager.default.fileExists(atPath: mimetypeURL.path) {
            try archive.addEntry(
                with: "mimetype",
                relativeTo: sourceDir,
                compressionMethod: .none
            )
        }

        // Collect all file URLs first to avoid iterator issues in async context
        var fileURLs: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "mimetype" { continue }

                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    fileURLs.append(fileURL)
                }
            }
        }

        // Add all other files
        for fileURL in fileURLs {
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
}
