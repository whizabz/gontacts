import CoreImage.CIFilterBuiltins
import SwiftUI

/// The ticked fields as a QR code. The Camera app reads a vCard QR code and offers to add the contact.
struct ContactQRView: View {
    /// A copy of the contact holding only the fields chosen on the Share Contact screen.
    let contact: Contact

    /// A QR code holds roughly 2.9 KB at the lowest error correction; a vCard past that can't be encoded.
    private static let maxBytes = 2_900

    private var qrImage: UIImage? { Self.makeImage(from: contact.vCard) }

    var body: some View {
        VStack(spacing: 20) {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .background(.white, in: .rect(cornerRadius: 28))
                    .frame(maxWidth: 360)
                    .accessibilityLabel("QR code for \(contact.displayName)")
                VStack(spacing: 4) {
                    Text(contact.displayName).font(.title2.bold())
                    Text("Scan with the Camera app to add this contact.").font(.subheadline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            } else {
                ContentUnavailableView("Too Much for a QR Code", systemImage: "qrcode",
                                       description: Text("Go back and untick some fields, such as addresses or notes."))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let image = qrImage {
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("QR code for \(contact.displayName)", image: Image(uiImage: image))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    /// Black-on-white QR image, scaled up crisply, or nil when the text is too long.
    static func makeImage(from text: String) -> UIImage? {
        let data = Data(text.utf8)
        guard data.count <= maxBytes else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
