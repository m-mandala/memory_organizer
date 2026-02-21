import SwiftUI

struct HomeView: View {
    @Environment(LibraryViewModel.self) private var viewModel
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statCards
                    scanButton
                    progressSection
                }
                .padding()
            }
            .navigationTitle("Memory Organizer")
            .alert("Photo Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please grant full photo library access in Settings to scan your library.")
            }
        }
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Photos",
                value: "\(viewModel.totalPhotos)",
                icon: "photo.stack",
                color: .blue
            )
            StatCard(
                title: "Duplicates",
                value: "\(viewModel.duplicatesFound)",
                icon: "doc.on.doc",
                color: .orange
            )
            StatCard(
                title: "Burst Extras",
                value: "\(viewModel.burstsFound)",
                icon: "burst",
                color: .purple
            )
            StatCard(
                title: "Clusters",
                value: "\(viewModel.clustersFound)",
                icon: "sparkles.rectangle.stack",
                color: .green
            )
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            if case .permissionDenied = viewModel.scanState {
                showPermissionAlert = true
            } else {
                Task { await viewModel.scanLibrary() }
            }
        } label: {
            HStack {
                if case .scanning = viewModel.scanState {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }
                Text(scanButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(scanButtonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isScanning)
    }

    private var scanButtonTitle: String {
        switch viewModel.scanState {
        case .scanning(let phase, _): return phase
        case .done: return "Re-Scan Library"
        case .permissionDenied: return "Grant Permission"
        default: return "Scan Library"
        }
    }

    private var scanButtonColor: Color {
        switch viewModel.scanState {
        case .permissionDenied: return .red
        default: return .blue
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.scanState { return true }
        return false
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        if case .scanning(let phase, let progress) = viewModel.scanState {
            VStack(alignment: .leading, spacing: 8) {
                Text(phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .tint(.blue)
                    .animation(.easeInOut, value: progress)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
            }
            Text(value)
                .font(.largeTitle.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
