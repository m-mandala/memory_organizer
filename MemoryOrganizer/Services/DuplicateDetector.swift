import Vision
import Photos
import UIKit

actor DuplicateDetector {
    private let threshold: Float = 0.3
    // Compare each photo only against its 150 nearest temporal neighbours.
    // Real duplicates (screenshots saved twice, burst extras, edits) are taken
    // within seconds of each other, so this catches virtually all of them while
    // keeping complexity at O(n × windowSize) instead of O(n²).
    private let windowSize = 150

    func detect(
        assets: [PhotoAsset],
        progress: @Sendable (Double) -> Void
    ) async -> [DuplicateGroup] {
        // Sort ascending by creation date so temporal neighbours are adjacent.
        let sorted = assets.sorted {
            ($0.phAsset.creationDate ?? .distantPast) < ($1.phAsset.creationDate ?? .distantPast)
        }
        let count = sorted.count
        guard count > 0 else { return [] }

        // Sliding window of recent (index, asset, featurePrint) tuples.
        // Oldest entry is evicted once capacity exceeds windowSize, keeping
        // peak memory proportional to windowSize, not the full library size.
        var window: [(idx: Int, asset: PhotoAsset, fp: VNFeaturePrintObservation)] = []
        window.reserveCapacity(windowSize + 1)

        var visited = Set<Int>()
        var groups: [DuplicateGroup] = []

        for i in 0..<count {
            let asset = sorted[i]

            guard
                let image   = await loadImage(asset: asset),
                let cgImage = image.cgImage
            else {
                if i % 100 == 0 {
                    let p = Double(i + 1) / Double(count)
                    await MainActor.run { progress(p) }
                }
                continue
            }

            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])

            guard let fp = request.results?.first as? VNFeaturePrintObservation else {
                continue
            }

            // Compare against everything currently in the window.
            if !visited.contains(i) {
                var group = [asset]
                visited.insert(i)

                for entry in window where !visited.contains(entry.idx) {
                    var distance: Float = 0
                    try? fp.computeDistance(&distance, to: entry.fp)
                    if distance < threshold {
                        group.append(entry.asset)
                        visited.insert(entry.idx)
                    }
                }

                if group.count > 1 {
                    groups.append(DuplicateGroup(assets: group, keepIndex: 0))
                }
            }

            // Slide the window forward, evicting the oldest entry.
            window.append((idx: i, asset: asset, fp: fp))
            if window.count > windowSize {
                window.removeFirst()
            }

            if i % 100 == 0 {
                let p = Double(i + 1) / Double(count)
                await MainActor.run { progress(p) }
            }
        }

        return groups
    }

    // MARK: - Image loading

    private func loadImage(asset: PhotoAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            final class Once { var done = false }
            let once = Once()
            PHImageManager.default().requestImage(
                for: asset.phAsset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard !once.done else { return }
                once.done = true
                continuation.resume(returning: image)
            }
        }
    }
}
