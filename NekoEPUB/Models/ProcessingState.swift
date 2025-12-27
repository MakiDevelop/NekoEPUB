//
//  ProcessingState.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation

enum ProcessingState: Equatable {
    case idle
    case processing(progress: Double, message: String)
    case completed(outputURL: URL)
    case error(message: String)

    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }

    var outputURL: URL? {
        if case .completed(let url) = self {
            return url
        }
        return nil
    }
}
