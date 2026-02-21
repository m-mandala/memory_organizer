import Foundation
import Observation

@Observable
final class BurstGroup: Identifiable {
    let id: String  // burst identifier
    var frames: [ScoredFrame]
    var keepIndex: Int

    init(burstIdentifier: String, frames: [ScoredFrame]) {
        self.id = burstIdentifier
        self.frames = frames
        // Auto-select highest quality frame
        self.keepIndex = frames.indices.max(by: { frames[$0].score < frames[$1].score }) ?? 0
    }

    var bestFrame: ScoredFrame { frames[keepIndex] }

    var framesToDelete: [PhotoAsset] {
        frames.enumerated().compactMap { index, frame in
            index == keepIndex ? nil : frame.asset
        }
    }

    var isSelected: Bool = false
}

struct ScoredFrame: Identifiable {
    let id = UUID()
    let asset: PhotoAsset
    let score: Double
    let sharpness: Double
    let exposure: Double
    let faceQuality: Double
    let motionStability: Double
}
