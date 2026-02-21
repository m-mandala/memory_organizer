import Foundation

@Observable
final class DuplicateGroup: Identifiable {
    let id = UUID()
    var assets: [PhotoAsset]
    var keepIndex: Int

    init(assets: [PhotoAsset], keepIndex: Int = 0) {
        self.assets = assets
        self.keepIndex = keepIndex
    }

    var assetToKeep: PhotoAsset { assets[keepIndex] }

    var assetsToDelete: [PhotoAsset] {
        assets.enumerated().compactMap { index, asset in
            index == keepIndex ? nil : asset
        }
    }

    var isSelected: Bool = false
}
