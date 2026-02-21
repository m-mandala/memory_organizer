import SwiftUI

struct AIClusterView: View {
    @Environment(LibraryViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.memoryClusters.isEmpty {
                    emptyState
                } else {
                    clusterGrid
                }
            }
            .navigationTitle("AI Clusters")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Clusters Yet", systemImage: "sparkles.rectangle.stack")
        } description: {
            Text("Scan your library from the Home tab to group your memories.")
        }
    }

    private var clusterGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("V1 groups photos by month. V2 will use CoreML for semantic clustering and image generation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(viewModel.memoryClusters) { cluster in
                        ClusterCard(cluster: cluster) {
                            Task { await viewModel.generateMemory(for: cluster) }
                        }
                    }
                }
                .padding()
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Cluster Card

struct ClusterCard: View {
    let cluster: MemoryCluster
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover photo
            coverImage
                .frame(height: 140)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(cluster.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(cluster.assetCount) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                generateButton
            }
            .padding(10)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let generated = cluster.generatedImage {
            Image(uiImage: generated)
                .resizable()
                .scaledToFill()
        } else if let cover = cluster.coverAsset, let thumb = cover.thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay {
                    Image(systemName: "photo.stack")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .task {
                    await cluster.coverAsset?.loadThumbnail(targetSize: CGSize(width: 300, height: 300))
                }
        }
    }

    private var generateButton: some View {
        Button(action: onGenerate) {
            HStack(spacing: 4) {
                if cluster.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(cluster.isGenerating ? "Generating…" : "Generate Memory")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(cluster.generatedImage != nil ? Color.green : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(cluster.isGenerating)
        .animation(.easeInOut, value: cluster.isGenerating)
    }
}
