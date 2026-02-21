import Photos
import UIKit

@Observable
final class PhotoAsset: Identifiable {
    let id: String
    let phAsset: PHAsset
    var thumbnail: UIImage?

    init(phAsset: PHAsset) {
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
    }

    func loadThumbnail(targetSize: CGSize = CGSize(width: 200, height: 200)) async {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        thumbnail = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
