//
//  CompressionSettings.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation

struct CompressionSettings {
    var quality: Double = 0.6  // 60% quality
    var format: CompressionFormat = .jpeg

    var qualityPercentage: Int {
        Int(quality * 100)
    }
}

enum CompressionFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case webp = "WebP"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .webp:
            return "webp"
        }
    }

    var mimeType: String {
        switch self {
        case .jpeg:
            return "image/jpeg"
        case .webp:
            return "image/webp"
        }
    }
}
