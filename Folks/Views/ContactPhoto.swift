import UIKit

/// The profile photo as JPEG data for a vCard.
enum ContactPhoto {
    /// Bundled demo photos are read locally; others are downloaded. Scaled down so the card stays small.
    /// nil when there's no photo or it can't be loaded, in which case the card is shared without one.
    static func jpeg(for url: URL?, maxSide: CGFloat = 512) async -> Data? {
        guard let url else { return nil }
        let image: UIImage?
        if let local = SampleData.image(for: url) {
            image = local
        } else if let (data, _) = try? await URLSession.shared.data(from: url) {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        guard let image else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.85) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension Contact {
    /// Writes the vCard to a temporary `.vcf` named after the contact and returns its URL.
    /// The profile photo goes in when this contact still has one (see `keeping`).
    func writeVCardFile() async throws -> URL {
        let name = displayName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name).vcf")
        let photo = await ContactPhoto.jpeg(for: photoURL)
        try vCard(withPhoto: photo).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
