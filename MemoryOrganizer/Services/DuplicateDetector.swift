import Vision
import Photos
import UIKit

actor DuplicateDetector {
    private let threshold: Float = 0.3
    private let batchSize = 50

    // Returns groups of near-duplicate PhotoAssets (each group has 2+ photos)
    func detect(assets: [PhotoAsset], progress: @Sendable (Double) -> Void) async -> [DuplicateGroup] {
        var prints: [(PhotoAsset, VNFeaturePrintObservation)] = []

        // Process in batches
        let batches = stride(from: 0, to: assets.count, by: batchSize).map {
            Array(assets[$0..<min($0 + batchSize, assets.count)])
        }

        var processed = 0
        for batch in batches {
            let batchPrints = await computeFeaturePrints(for: batch)
            prints.append(contentsOf: batchPrints)
            processed += batch.count
            await MainActor.run { progress(Double(processed) / Double(assets.count)) }
        }

        return buildGroups(from: prints)
    }

    // MARK: - Feature print computation

    private func computeFeaturePrints(for assets: [PhotoAsset]) async -> [(PhotoAsset, VNFeaturePrintObservation)] {
        var results: [(PhotoAsset, VNFeaturePrintObservation)] = []

        for asset in assets {
            guard let image = await loadImage(asset: asset) else { continue }
            guard let cgImage = image.cgImage else { continue }

            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                if let observation = request.results?.first as? VNFeaturePrintObservation {
                    results.append((asset, observation))
                }
            } catch {
                // Skip assets that fail
            }
        }

        return results
    }

    // MARK: - Grouping

    private func buildGroups(from prints: [(PhotoAsset, VNFeaturePrintObservation)]) -> [DuplicateGroup] {
        var visited = Set<Int>()
        var groups: [DuplicateGroup] = []

        for i in 0..<prints.count {
            guard !visited.contains(i) else { continue }

            var group = [prints[i].0]
            visited.insert(i)

            for j in (i + 1)..<prints.count {
                guard !visited.contains(j) else { continue }

                var distance: Float = 0
                do {
                    try prints[i].1.computeDistance(&distance, to: prints[j].1)
                } catch {
                    continue
                }

                if distance < threshold {
                    group.append(prints[j].0)
                    visited.insert(j)
                }
            }

            if group.count > 1 {
                // Keep the most recently taken photo by default
                groups.append(DuplicateGroup(assets: group, keepIndex: 0))
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
            PHImageManager.default().requestImage(
                for: asset.phAsset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
