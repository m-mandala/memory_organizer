import Photos
import UIKit
import Observation

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
        options.deliveryMode = .opportunistic  // may fire twice (degraded then full)
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        thumbnail = await withCheckedContinuation { continuation in
            // .opportunistic can call the handler twice; guard against double-resume.
            final class Once { var done = false }
            let once = Once()
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !once.done else { return }
                once.done = true
                continuation.resume(returning: image)
            }
        }
    }
}
