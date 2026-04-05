import SwiftUI

struct ImageCropView: View {
    let image: NSImage
    @Binding var cropRect: CGRect // normalized 0...1 (origin top-left)

    private let handleSize: CGFloat = 12
    private let minSize: CGFloat = 0.05

    private enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(container: geo.size, imageSize: image.size)
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                overlayMask(in: imageRect)

                cropBorder(in: imageRect)

                ForEach(Array(Handle.allCases.enumerated()), id: \.offset) { _, handle in
                    cropHandle(handle, in: imageRect)
                }
            }
            .coordinateSpace(name: "imageCrop")
        }
        .clipped()
        .contentShape(Rectangle())
        .accessibilityIdentifier("quickEdit.cropView")
    }

    private func overlayMask(in imageRect: CGRect) -> some View {
        let crop = cropRectInView(imageRect: imageRect)
        return Path { path in
            path.addRect(imageRect)
            path.addRect(crop)
        }
        .fill(.black.opacity(0.35), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func cropBorder(in imageRect: CGRect) -> some View {
        let crop = cropRectInView(imageRect: imageRect)
        return Rectangle()
            .path(in: crop)
            .stroke(.white, lineWidth: 2)
            .shadow(radius: 1)
            .allowsHitTesting(false)
    }

    private func cropHandle(_ handle: Handle, in imageRect: CGRect) -> some View {
        let crop = cropRectInView(imageRect: imageRect)
        let pos = handlePosition(handle, cropRect: crop)

        return Circle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .position(pos)
            .accessibilityIdentifier("quickEdit.cropHandle.\(handle)")
            .accessibilityAddTraits(.isButton)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("imageCrop"))
                    .onChanged { value in
                        updateCrop(for: handle, location: value.location, imageRect: imageRect)
                    }
            )
            .shadow(radius: 1)
    }

    private func updateCrop(for handle: Handle, location: CGPoint, imageRect: CGRect) {
        let p = normalizedPoint(location, in: imageRect)
        var x0 = cropRect.minX
        var y0 = cropRect.minY
        var x1 = cropRect.maxX
        var y1 = cropRect.maxY

        switch handle {
        case .topLeft:
            x0 = min(p.x, x1 - minSize)
            y0 = min(p.y, y1 - minSize)
        case .topRight:
            x1 = max(p.x, x0 + minSize)
            y0 = min(p.y, y1 - minSize)
        case .bottomLeft:
            x0 = min(p.x, x1 - minSize)
            y1 = max(p.y, y0 + minSize)
        case .bottomRight:
            x1 = max(p.x, x0 + minSize)
            y1 = max(p.y, y0 + minSize)
        }

        cropRect = CGRect(x: clamp01(x0), y: clamp01(y0), width: clamp01(x1) - clamp01(x0), height: clamp01(y1) - clamp01(y0))
    }

    private func normalizedPoint(_ point: CGPoint, in imageRect: CGRect) -> CGPoint {
        let x = (point.x - imageRect.minX) / imageRect.width
        let y = (point.y - imageRect.minY) / imageRect.height
        return CGPoint(x: clamp01(x), y: clamp01(y))
    }

    private func cropRectInView(imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + cropRect.minX * imageRect.width,
            y: imageRect.minY + cropRect.minY * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )
    }

    private func handlePosition(_ handle: Handle, cropRect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight: CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft: CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight: CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func fittedImageRect(container: CGSize, imageSize: CGSize) -> CGRect {
        guard container.width > 0, container.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height

        let size: CGSize
        if containerAspect > imageAspect {
            size = CGSize(width: container.height * imageAspect, height: container.height)
        } else {
            size = CGSize(width: container.width, height: container.width / imageAspect)
        }

        let origin = CGPoint(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2
        )
        return CGRect(origin: origin, size: size)
    }

    private func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}
