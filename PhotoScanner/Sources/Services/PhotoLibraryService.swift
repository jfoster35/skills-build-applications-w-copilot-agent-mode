import Photos
import UIKit

/// Saves processed scans to the Photos library, into a named album that is
/// created on demand (PRD §8 step 6). Add-only authorization.
final class PhotoLibraryService {

    enum SaveError: Error {
        case unauthorized
        case albumUnavailable
        case saveFailed
    }

    /// Request add-only Photos authorization.
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    var currentStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }

    /// Save an image into the album, creating the album if needed.
    func save(image: UIImage, toAlbumNamed albumName: String) async throws {
        let status = currentStatus
        guard status == .authorized || status == .limited else {
            throw SaveError.unauthorized
        }

        let collection = try await fetchOrCreateAlbum(named: albumName)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let collection,
                   let placeholder = creationRequest.placeholderForCreatedAsset,
                   let albumChange = PHAssetCollectionChangeRequest(for: collection) {
                    albumChange.addAssets([placeholder] as NSArray)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveError.saveFailed)
                }
            }
        }
    }

    private func fetchOrCreateAlbum(named name: String) async throws -> PHAssetCollection? {
        if let existing = fetchAlbum(named: name) { return existing }

        var placeholderID: String?
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveError.albumUnavailable)
                }
            }
        }

        guard let id = placeholderID else { return nil }
        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
        return result.firstObject
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        return result.firstObject
    }
}
