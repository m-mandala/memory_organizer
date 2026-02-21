import SwiftUI
import Photos

@Observable
@MainActor
final class LibraryViewModel {

    // MARK: - State

    enum ScanState: Equatable {
        case idle
        case requestingPermission
        case scanning(phase: String, progress: Double)
        case done
        case permissionDenied
        case error(String)
    }

    var scanState: ScanState = .idle
    var duplicateGroups: [DuplicateGroup] = []
    var burstGroups: [BurstGroup] = []
    var memoryClusters: [MemoryCluster] = []

    var totalPhotos: Int = 0
    var duplicatesFound: Int = 0
    var burstsFound: Int = 0
    var clustersFound: Int = 0

    // MARK: - Private

    private let photoService = PhotoLibraryService()
    private let duplicateDetector = DuplicateDetector()
    private let generationService: any ImageGenerationService = MockImageGenerationService()

    // MARK: - Permissions

    func requestPermissions() async {
        scanState = .requestingPermission
        let status = await photoService.requestAuthorization()
        if status == .authorized || status == .limited {
            scanState = .idle
        } else {
            scanState = .permissionDenied
        }
    }

    // MARK: - Scanning

    func scanLibrary() async {
        guard scanState == .idle || scanState == .done else { return }

        duplicateGroups = []
        burstGroups = []
        memoryClusters = []

        // Phase 1: Fetch all photos
        scanState = .scanning(phase: "Fetching library…", progress: 0)
        let allAssets = await photoService.fetchAllPhotos()
        totalPhotos = allAssets.count

        // Load thumbnails for display (fire-and-forget)
        Task.detached(priority: .background) {
            for asset in allAssets {
                await asset.loadThumbnail()
            }
        }

        // Phase 2: Detect duplicates
        scanState = .scanning(phase: "Finding duplicates…", progress: 0)
        let duplicates = await duplicateDetector.detect(assets: allAssets) { [weak self] p in
            Task { @MainActor [weak self] in
                self?.scanState = .scanning(phase: "Finding duplicates…", progress: p)
            }
        }
        duplicateGroups = duplicates
        duplicatesFound = duplicates.reduce(0) { $0 + $1.assetsToDelete.count }

        // Phase 3: Detect bursts
        scanState = .scanning(phase: "Analyzing bursts…", progress: 0)
        let burstReps = await photoService.fetchBurstRepresentatives()
        let burstAnalyzer = BurstAnalyzer(photoService: photoService)
        let bursts = await burstAnalyzer.analyzeBursts(representatives: burstReps) { [weak self] p in
            Task { @MainActor [weak self] in
                self?.scanState = .scanning(phase: "Analyzing bursts…", progress: p)
            }
        }
        burstGroups = bursts
        burstsFound = bursts.reduce(0) { $0 + $1.framesToDelete.count }

        // Phase 4: Cluster memories (lightweight V1 — group by month)
        scanState = .scanning(phase: "Clustering memories…", progress: 0.5)
        memoryClusters = buildMemoryClusters(from: allAssets)
        clustersFound = memoryClusters.count

        scanState = .done
    }

    // MARK: - Deletion

    func deleteSelectedDuplicates() async throws {
        let toDelete = duplicateGroups
            .filter(\.isSelected)
            .flatMap(\.assetsToDelete)

        try await photoService.delete(assets: toDelete)

        // Remove deleted groups from list
        duplicateGroups.removeAll(where: \.isSelected)
        duplicatesFound = duplicateGroups.reduce(0) { $0 + $1.assetsToDelete.count }
    }

    func deleteSelectedBursts() async throws {
        let toDelete = burstGroups
            .filter(\.isSelected)
            .flatMap(\.framesToDelete)

        try await photoService.delete(assets: toDelete)
        burstGroups.removeAll(where: \.isSelected)
        burstsFound = burstGroups.reduce(0) { $0 + $1.framesToDelete.count }
    }

    // MARK: - AI Generation

    func generateMemory(for cluster: MemoryCluster) async {
        cluster.isGenerating = true
        do {
            let image = try await generationService.generate(from: cluster)
            cluster.generatedImage = image
        } catch {
            // surface error to user via alert in view
        }
        cluster.isGenerating = false
    }

    // MARK: - Cluster building (V1: group by month)

    private func buildMemoryClusters(from assets: [PhotoAsset]) -> [MemoryCluster] {
        let calendar = Calendar.current
        var byMonth: [String: [PhotoAsset]] = [:]

        for asset in assets {
            guard let date = asset.phAsset.creationDate else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else { continue }

            let key = "\(year)-\(String(format: "%02d", month))"
            byMonth[key, default: []].append(asset)
        }

        return byMonth.sorted(by: { $0.key > $1.key }).map { key, assets in
            // Format title e.g. "January 2024"
            let parts = key.split(separator: "-")
            var title = key
            if parts.count == 2,
               let year = Int(parts[0]),
               let month = Int(parts[1]) {
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                if let date = Calendar.current.date(from: comps) {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "MMMM yyyy"
                    title = fmt.string(from: date)
                }
            }
            return MemoryCluster(assets: assets, title: title)
        }
    }
}
