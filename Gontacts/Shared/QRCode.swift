import CoreImage.CIFilterBuiltins
import UIKit

/// Turns text into a QR code. Used by the QR screen in the app and by the QR widgets.
enum QRCode {
    /// A QR code holds roughly 2.9 KB at the lowest error correction; a vCard past that can't be encoded.
    static let maxBytes = 2_900

    /// Black-on-white QR image, scaled up crisply, or nil when the text is too long.
    ///
    /// With `modulesOnly` the background is transparent, so the code can be drawn in any colour as a template image.
    static func image(from text: String, modulesOnly: Bool = false) -> UIImage? {
        let data = Data(text.utf8)
        guard data.count <= maxBytes else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        // Widgets can't always render a Core Image result to the screen (the image comes out blank), so read the
        // modules into an array with the software renderer and draw the code ourselves.
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        let side = cg.width
        var pixels = [UInt8](repeating: 255, count: side * side)
        guard let bitmap = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        bitmap.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        let module: CGFloat = 8
        let size = CGSize(width: CGFloat(side) * module, height: CGFloat(side) * module)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !modulesOnly
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            if !modulesOnly {
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            UIColor.black.setFill()
            for y in 0..<side {
                for x in 0..<side where pixels[y * side + x] < 128 {
                    ctx.fill(CGRect(x: CGFloat(x) * module, y: CGFloat(y) * module, width: module, height: module))
                }
            }
        }
    }
}
