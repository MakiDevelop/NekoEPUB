//
//  EPubMetadata.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation

struct EPubMetadata {
    let identifier: String
    let title: String
    let author: String
    let language: String
    let date: String
    let isDoublePage: Bool  // 是否為雙頁掃描模式

    static var `default`: EPubMetadata {
        let dateFormatter = ISO8601DateFormatter()
        return EPubMetadata(
            identifier: UUID().uuidString,
            title: "Photo Album",
            author: "NekoEPUB",
            language: "en",
            date: dateFormatter.string(from: Date()),
            isDoublePage: false
        )
    }

    init(identifier: String, title: String, author: String, language: String, date: String, isDoublePage: Bool = false) {
        self.identifier = identifier
        self.title = title
        self.author = author
        self.language = language
        self.date = date
        self.isDoublePage = isDoublePage
    }
}
