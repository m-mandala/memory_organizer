import Photos
import UIKit

actor PhotoLibraryService {

    // MARK: - Permissions

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Fetching

    func fetchAllPhotos() -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(phAsset: asset))
        }
        return assets
    }

    func fetchBurstRepresentatives() -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND representsBurst == YES",
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(phAsset: asset))
        }
        return assets
    }

    func fetchBurstMembers(burstIdentifier: String) -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true

        let result = PHAsset.fetchAssets(withBurstIdentifier: burstIdentifier, options: options)
        var assets: [PhotoAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(phAsset: asset))
        }
        return assets
    }

    // MARK: - Deletion

    func delete(assets: [PhotoAsset]) async throws {
        let phAssets = assets.map(\.phAsset) as NSArray
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(phAssets)
        }
    }

    // MARK: - Full-resolution image

    func fullImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
