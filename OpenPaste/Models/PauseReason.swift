//
//  PauseReason.swift
//  OpenPaste
//

import Foundation

enum PauseReason: Sendable, Equatable {
    case manual
    case timed(duration: TimeInterval)
    case smartDetect(appName: String)
}
