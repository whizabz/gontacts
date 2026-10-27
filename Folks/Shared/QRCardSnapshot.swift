import Foundation

/// A contact card as the QR widgets need it: how it looks, and the vCard its QR code holds.
struct QRCardSnapshot: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var colorIndex: Int
    var vCard: String

    /// The built-in card that shares everything.
    static let fullID = "full"
}
