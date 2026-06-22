import UIKit

/// A single captured + processed scan held for the current session.
///
/// The full-resolution image is written to a temporary file on disk (not kept
/// in memory) so the thumbnail strip stays lightweight. The permanent copy
/// lives in the user's Photos library; `fullImageURL` is only used for the
/// in-session full-screen preview.
struct ScannedPhoto: Identifiable, Equatable {
    let id: UUID
    let thumbnail: UIImage
    /// Location of the processed full-resolution image in the caches directory.
    let fullImageURL: URL
    let capturedAt: Date

    init(id: UUID = UUID(), thumbnail: UIImage, fullImageURL: URL, capturedAt: Date = Date()) {
        self.id = id
        self.thumbnail = thumbnail
        self.fullImageURL = fullImageURL
        self.capturedAt = capturedAt
    }

    static func == (lhs: ScannedPhoto, rhs: ScannedPhoto) -> Bool {
        lhs.id == rhs.id
    }
}
