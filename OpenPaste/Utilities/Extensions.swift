import Foundation
import AppKit
import SwiftUI

extension Color {
    static let brandAccent = DS.Colors.accent
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

extension AppInfo {
    var appIcon: NSImage? {
        if let path = iconPath, FileManager.default.fileExists(atPath: path) {
            return NSImage(contentsOfFile: path)
        }
        if !bundleId.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension String {
    func truncated(to maxLength: Int, trailing: String = "…") -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength)) + trailing
    }
}

extension Data {
    var humanReadableSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}

extension NSImage {
    func thumbnail(maxSize: CGFloat = 60) -> NSImage {
        let aspect = size.width / size.height
        let newSize: NSSize
        if aspect > 1 {
            newSize = NSSize(width: maxSize, height: maxSize / aspect)
        } else {
            newSize = NSSize(width: maxSize * aspect, height: maxSize)
        }

        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        img.unlockFocus()
        return img
    }

    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)?
                .cropping(to: rect) else { return nil }
        return NSImage(cgImage: cgImage, size: rect.size)
    }
}
