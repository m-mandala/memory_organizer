import SwiftUI

struct BurstsView: View {
    @Environment(LibraryViewModel.self) private var viewModel
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    private var selectedGroups: [BurstGroup] {
        viewModel.burstGroups.filter(\.isSelected)
    }

    private var totalToDelete: Int {
        selectedGroups.flatMap(\.framesToDelete).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.burstGroups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationTitle("Bursts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !selectedGroups.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        deleteButton
                    }
                }
            }
            .confirmationDialog(
                "Delete \(totalToDelete) burst frame\(totalToDelete == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(totalToDelete) Frame\(totalToDelete == 1 ? "" : "s")", role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteSelectedBursts()
                        } catch {
                            deleteError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("These frames will be moved to the Photos trash and can be recovered within 30 days.")
            }
            .alert("Delete Failed", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Bursts Found", systemImage: "burst")
        } description: {
            Text("Scan your library from the Home tab to detect burst sequences.")
        }
    }

    private var groupList: some View {
        List {
            Section {
                Text("\(viewModel.burstGroups.count) bursts · \(viewModel.burstsFound) extra frames")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.burstGroups) { group in
                BurstGroupRow(group: group)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete \(totalToDelete) Frame\(totalToDelete == 1 ? "" : "s")", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
}

// MARK: - Burst Group Row

struct BurstGroupRow: View {
    @Bindable var group: BurstGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: group.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(group.isSelected ? .blue : .secondary)
                    .font(.title3)
                Text("\(group.frames.count) frames")
                    .fontWeight(.medium)
                Spacer()
                Text("Keep best · delete \(group.frames.count - 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { group.isSelected.toggle() }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.frames.enumerated()), id: \.element.id) { index, frame in
                        BurstFrameCell(
                            frame: frame,
                            isKeep: index == group.keepIndex,
                            onTapKeep: { group.keepIndex = index }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Burst Frame Cell

struct BurstFrameCell: View {
    let frame: ScoredFrame
    let isKeep: Bool
    let onTapKeep: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let thumb = frame.asset.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay { ProgressView() }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isKeep ? Color.green : Color.clear, lineWidth: 3)
            )

            VStack(spacing: 2) {
                if isKeep {
                    Text("BEST")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                ScoreBadge(score: frame.score)
            }
            .padding(.bottom, 6)
        }
        .onTapGesture(perform: onTapKeep)
        .task { await frame.asset.loadThumbnail(targetSize: CGSize(width: 200, height: 200)) }
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double

    var color: Color {
        switch score {
        case 0.8...: return .green
        case 0.5...: return .yellow
        default: return .red
        }
    }

    var body: some View {
        Text(String(format: "%.0f%%", score * 100))
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
