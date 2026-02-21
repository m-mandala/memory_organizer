# MemoryOrganizer

A native iOS 18+ app that de-clutters your Photos library using on-device compute.

## Features

### V1
- **Duplicate Detection** — `VNGenerateImageFeaturePrintRequest` computes feature vectors; pairwise distance < 0.3 groups near-duplicates. Review side-by-side, pick which to keep, confirm deletion (moves to 30-day trash).
- **Burst Analysis** — fetches burst sequences via `PHAsset` burst API, scores each frame on sharpness (40%), exposure (30%), face quality (20%), and motion stability (10%). Auto-selects the best frame; override supported.
- **AI Clusters** — groups photos by month (V1 placeholder). Each cluster has a "Generate Memory" button wired to `MockImageGenerationService`.

### V2 Hooks
- `ImageGenerationService` protocol is ready for a CoreML Stable Diffusion or Apple ImagePlayground backend.
- Swap `MockImageGenerationService` with a real implementation in `MemoryOrganizerApp.swift`.

## Requirements
- iOS 18+
- Physical iPhone (simulator has no real photo library)
- Full photo library access

## Project Structure

```
MemoryOrganizer/
├── MemoryOrganizerApp.swift
├── ContentView.swift
├── Info.plist
├── Models/
│   ├── PhotoAsset.swift
│   ├── DuplicateGroup.swift
│   ├── BurstGroup.swift
│   └── MemoryCluster.swift
├── Services/
│   ├── PhotoLibraryService.swift
│   ├── DuplicateDetector.swift
│   ├── BurstAnalyzer.swift
│   ├── ImageQualityAnalyzer.swift
│   └── ImageGenerationService.swift
├── ViewModels/
│   └── LibraryViewModel.swift
└── Views/
    ├── HomeView.swift
    ├── DuplicatesView.swift
    ├── BurstsView.swift
    └── AIClusterView.swift
```

## Setup

1. Open `MemoryOrganizer.xcodeproj` in Xcode 16+
2. Set your development team in Signing & Capabilities
3. Run on a physical iPhone
4. Grant Full Photo Library access when prompted
5. Tap **Scan Library** on the Home tab
