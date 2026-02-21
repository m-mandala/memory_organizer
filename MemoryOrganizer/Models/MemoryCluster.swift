import Foundation
import UIKit

@Observable
final class MemoryCluster: Identifiable {
    let id = UUID()
    var assets: [PhotoAsset]
    var title: String
    var generatedImage: UIImage?
    var isGenerating: Bool = false

    init(assets: [PhotoAsset], title: String) {
        self.assets = assets
        self.title = title
    }

    var coverAsset: PhotoAsset? { assets.first }
    var assetCount: Int { assets.count }
}
