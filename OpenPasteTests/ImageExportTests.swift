import AppKit
import Foundation
import Testing

@testable import OpenPaste

struct ImageExportTests {
    private func makeTwoToneImage(width: Int, height: Int) throws -> NSImage {
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )

        // NSBitmapImageRep uses origin at bottom-left.
        // Bottom half = blue, top half = red.
        for y in 0..<height {
            for x in 0..<width {
                let color: NSColor = y < height / 2 ? .blue : .red
                rep.setColor(color, atX: x, y: y)
            }
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }

    private func assertMostly(_ color: NSColor, equals expected: NSColor, tolerance: CGFloat = 0.15) {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        let e = expected.usingColorSpace(.deviceRGB) ?? expected

        #expect(abs(c.redComponent - e.redComponent) <= tolerance)
        #expect(abs(c.greenComponent - e.greenComponent) <= tolerance)
        #expect(abs(c.blueComponent - e.blueComponent) <= tolerance)
    }

    /// Samples a pixel using normalized coordinates with origin at top-left.
    private func sample(
        _ rep: NSBitmapImageRep,
        normalizedX: CGFloat,
        normalizedYFromTop: CGFloat
    ) throws -> NSColor {
        let w = max(rep.pixelsWide, 1)
        let h = max(rep.pixelsHigh, 1)

        let x = min(max(Int(normalizedX * CGFloat(w - 1)), 0), w - 1)
        let yFromBottom = 1 - normalizedYFromTop
        let y = min(max(Int(yFromBottom * CGFloat(h - 1)), 0), h - 1)

        return try #require(rep.colorAt(x: x, y: y))
    }

    @Test func exportTIFF_cropRectUsesTopLeftOrigin() throws {
        let width = 80
        let height = 60
        let image = try makeTwoToneImage(width: width, height: height)

        let full = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                    scale: 1
                )
            )
        )

        // Bottom half in top-left space => y starts at 0.5
        let cropped = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0, y: 0.5, width: 1, height: 0.5),
                    scale: 1
                )
            )
        )

        #expect(cropped.pixelsWide == width)
        #expect(cropped.pixelsHigh == height / 2)

        let actualCenter = try #require(cropped.colorAt(x: cropped.pixelsWide / 2, y: cropped.pixelsHigh / 2))
        let expectedFromFull = try sample(full, normalizedX: 0.5, normalizedYFromTop: 0.75)
        assertMostly(actualCenter, equals: expectedFromFull)
    }

    @Test func exportTIFF_appliesScale_afterCropping() throws {
        let width = 100
        let height = 80
        let image = try makeTwoToneImage(width: width, height: height)

        let full = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                    scale: 1
                )
            )
        )

        let scaled = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                    scale: 0.5
                )
            )
        )

        #expect(scaled.pixelsWide == width / 2)
        #expect(scaled.pixelsHigh == height / 2)

        // Pick pixels far from the boundary to avoid interpolation artifacts.
        let expectedTop = try sample(full, normalizedX: 0.5, normalizedYFromTop: 0.1)
        let expectedBottom = try sample(full, normalizedX: 0.5, normalizedYFromTop: 0.9)
        let actualTop = try sample(scaled, normalizedX: 0.5, normalizedYFromTop: 0.1)
        let actualBottom = try sample(scaled, normalizedX: 0.5, normalizedYFromTop: 0.9)

        assertMostly(actualTop, equals: expectedTop)
        assertMostly(actualBottom, equals: expectedBottom)
    }

    @Test func exportTIFF_clampsCropRectOutsideBounds() throws {
        let width = 100
        let height = 50
        let image = try makeTwoToneImage(width: width, height: height)

        let full = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                    scale: 1
                )
            )
        )

        // Intentionally exceed maxX; should clamp to 1.0 (=> width ~ 10% of full).
        let cropped = try #require(
            NSBitmapImageRep(
                data: ImageExport.exportTIFF(
                    image: image,
                    cropRect: CGRect(x: 0.9, y: 0, width: 0.2, height: 1),
                    scale: 1
                )
            )
        )

        #expect(full.pixelsWide == width)
        #expect(cropped.pixelsWide == 10)
        #expect(cropped.pixelsHigh == height)
    }
}
