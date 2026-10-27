import SwiftUI

/// The ticked fields as a QR code. The Camera app reads a vCard QR code and offers to add the contact.
struct ContactQRView: View {
    /// A copy of the contact holding only the fields chosen on the Share Contact screen.
    let contact: Contact

    /// The contact card being shown, named under the code. Nil for a one-off pick of details.
    var card: ContactCard?

    private var qrImage: UIImage? { QRCode.image(from: contact.vCard) }

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
                VStack(spacing: 10) {
                    if let card {
                        CardTile(symbol: card.symbol, colorIndex: card.colorIndex, size: 44)
                        Text(card.name).font(.title2.bold())
                        Text(contact.displayName).font(.headline).foregroundStyle(.secondary)
                    } else {
                        Text(contact.displayName).font(.title2.bold())
                    }
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
}
