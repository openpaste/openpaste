import AppKit
import CoreGraphics
import Foundation

enum ImageExport {
    /// Returns a TIFF blob suitable for writing to NSPasteboard as `.tiff`.
    static func exportTIFF(image: NSImage, cropRect: CGRect, scale: CGFloat) -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image.tiffRepresentation ?? Data()
        }

        // cropRect is normalized (0...1) with origin at top-left, matching ImageCropView.
        let cropRect = cropRect.standardized
        func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }

        let x0 = clamp01(cropRect.minX)
        let y0 = clamp01(cropRect.minY)
        let x1 = clamp01(cropRect.maxX)
        let y1 = clamp01(cropRect.maxY)

        let normalized = CGRect(
            x: x0,
            y: y0,
            width: max(x1 - x0, 0),
            height: max(y1 - y0, 0)
        )

        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        let raw = CGRect(
            x: normalized.minX * w,
            y: normalized.minY * h,
            width: normalized.width * w,
            height: normalized.height * h
        )

        // Avoid `.integral` expanding the rect out-of-bounds (which would make cropping fail).
        let px0 = max(floor(raw.minX), 0)
        let py0 = max(floor(raw.minY), 0)
        let px1 = min(ceil(raw.maxX), w)
        let py1 = min(ceil(raw.maxY), h)

        let pixelRect = CGRect(
            x: px0,
            y: py0,
            width: max(px1 - px0, 1.0),
            height: max(py1 - py0, 1.0)
        )

        guard let cropped = cgImage.cropping(to: pixelRect) else {
            return image.tiffRepresentation ?? Data()
        }

        let output: CGImage
        if abs(scale - 1) < 0.0001 {
            output = cropped
        } else if let scaled = resize(cgImage: cropped, scale: scale) {
            output = scaled
        } else {
            return image.tiffRepresentation ?? Data()
        }

        let rep = NSBitmapImageRep(cgImage: output)
        return rep.representation(using: .tiff, properties: [:]) ?? Data()
    }

    private static func resize(cgImage: CGImage, scale: CGFloat) -> CGImage? {
        let s = max(scale, 0.01)
        let newWidth = max(Int(CGFloat(cgImage.width) * s), 1)
        let newHeight = max(Int(CGFloat(cgImage.height) * s), 1)

        let colorSpace = cgImage.colorSpace
            ?? CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let alphaInfo = CGImageAlphaInfo.premultipliedFirst
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: alphaInfo.rawValue))

        guard let ctx = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = CGInterpolationQuality.high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return ctx.makeImage()
    }
}
