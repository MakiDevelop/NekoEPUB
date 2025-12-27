//
//  FileService.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation

final class FileService {
    static let shared = FileService()

    private init() {}

    func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        return tempDir
    }

    func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    func copyFile(from source: URL, to destination: URL) throws {
        // Create parent directory if needed
        let parentDir = destination.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )
        }

        try FileManager.default.copyItem(at: source, to: destination)
    }

    func writeData(_ data: Data, to url: URL) throws {
        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )
        }

        try data.write(to: url)
    }

    func directorySize(at url: URL) throws -> Int64 {
        var size: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                size += Int64(fileSize)
            }
        }

        return size
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
