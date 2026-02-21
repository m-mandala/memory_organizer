import Photos
import UIKit

actor BurstAnalyzer {
    private let photoService: PhotoLibraryService
    private let qualityAnalyzer = ImageQualityAnalyzer()

    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }

    func analyzeBursts(
        representatives: [PhotoAsset],
        progress: @Sendable (Double) -> Void
    ) async -> [BurstGroup] {
        var groups: [BurstGroup] = []

        for (index, representative) in representatives.enumerated() {
            guard let burstId = representative.phAsset.burstIdentifier else { continue }

            let members = await photoService.fetchBurstMembers(burstIdentifier: burstId)
            let scoredFrames = await scoreFrames(members)

            if scoredFrames.count > 1 {
                groups.append(BurstGroup(burstIdentifier: burstId, frames: scoredFrames))
            }

            await MainActor.run {
                progress(Double(index + 1) / Double(representatives.count))
            }
        }

        return groups
    }

    // MARK: - Frame scoring

    private func scoreFrames(_ assets: [PhotoAsset]) async -> [ScoredFrame] {
        var scored: [ScoredFrame] = []

        for asset in assets {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            let image = await withCheckedContinuation { continuation in
                PHImageManager.default().requestImage(
                    for: asset.phAsset,
                    targetSize: CGSize(width: 1024, height: 1024),
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }

            guard let img = image else { continue }

            let scores = await qualityAnalyzer.analyze(image: img)

            scored.append(ScoredFrame(
                asset: asset,
                score: scores.composite,
                sharpness: scores.sharpness,
                exposure: scores.exposure,
                faceQuality: scores.faceQuality,
                motionStability: scores.motionStability
            ))
        }

        return scored
    }
}
