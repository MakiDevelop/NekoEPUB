//
//  ImageItem.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation
import AppKit

struct ImageItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var order: Int

    var filename: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    init(url: URL, order: Int) {
        self.id = UUID()
        self.url = url
        self.order = order
    }

    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id
    }
}
