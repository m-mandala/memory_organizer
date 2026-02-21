import UIKit

// MARK: - Protocol

protocol ImageGenerationService: Sendable {
    func canGenerate(for cluster: MemoryCluster) -> Bool
    func generate(from cluster: MemoryCluster) async throws -> UIImage
}

// MARK: - V1 Mock (returns highest-quality existing photo as stand-in)

final class MockImageGenerationService: ImageGenerationService {
    func canGenerate(for cluster: MemoryCluster) -> Bool {
        !cluster.assets.isEmpty
    }

    func generate(from cluster: MemoryCluster) async throws -> UIImage {
        // Simulate processing time
        try await Task.sleep(for: .seconds(1.5))

        // V1: return thumbnail of the first (cover) asset as a placeholder
        guard let cover = cluster.coverAsset else {
            throw GenerationError.noAssets
        }

        if let existing = cover.thumbnail {
            return existing
        }

        // Load thumbnail on demand
        await cover.loadThumbnail(targetSize: CGSize(width: 512, height: 512))
        return cover.thumbnail ?? UIImage(systemName: "photo")!
    }
}

// MARK: - V2 Hook (CoreML / Apple ImagePlayground placeholder)
// Uncomment and implement when targeting iOS 18.2+ with ImagePlayground entitlement.
//
// import ImagePlayground
//
// @available(iOS 18.2, *)
// final class ImagePlaygroundGenerationService: ImageGenerationService {
//     func canGenerate(for cluster: MemoryCluster) -> Bool { true }
//     func generate(from cluster: MemoryCluster) async throws -> UIImage {
//         // Use ImagePlaygroundViewController or CoreML Stable Diffusion
//         fatalError("V2 not yet implemented")
//     }
// }

// MARK: - Errors

enum GenerationError: LocalizedError {
    case noAssets

    var errorDescription: String? {
        switch self {
        case .noAssets: return "No photos in cluster to generate from."
        }
    }
}
