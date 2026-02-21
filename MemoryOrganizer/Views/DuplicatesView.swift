import SwiftUI

struct DuplicatesView: View {
    @Environment(LibraryViewModel.self) private var viewModel
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    private var selectedGroups: [DuplicateGroup] {
        viewModel.duplicateGroups.filter(\.isSelected)
    }

    private var totalToDelete: Int {
        selectedGroups.flatMap(\.assetsToDelete).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.duplicateGroups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationTitle("Duplicates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !selectedGroups.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        deleteButton
                    }
                }
            }
            .confirmationDialog(
                "Delete \(totalToDelete) photo\(totalToDelete == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(totalToDelete) Photo\(totalToDelete == 1 ? "" : "s")", role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteSelectedDuplicates()
                        } catch {
                            deleteError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("These photos will be moved to the Photos trash and can be recovered within 30 days.")
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

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Duplicates Found", systemImage: "checkmark.circle")
        } description: {
            Text("Scan your library from the Home tab to detect duplicate photos.")
        }
    }

    // MARK: - Group List

    private var groupList: some View {
        List {
            Section {
                Text("\(viewModel.duplicateGroups.count) groups · \(viewModel.duplicatesFound) extra photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.duplicateGroups) { group in
                DuplicateGroupRow(group: group)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete \(totalToDelete) Extra\(totalToDelete == 1 ? "" : "s")", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
}

// MARK: - Duplicate Group Row

struct DuplicateGroupRow: View {
    @Bindable var group: DuplicateGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selection toggle header
            HStack {
                Image(systemName: group.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(group.isSelected ? .blue : .secondary)
                    .font(.title3)
                Text("\(group.assets.count) similar photos")
                    .fontWeight(.medium)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { group.isSelected.toggle() }

            // Photo strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.assets.enumerated()), id: \.element.id) { index, asset in
                        DuplicatePhotoCell(
                            asset: asset,
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

// MARK: - Photo Cell

struct DuplicatePhotoCell: View {
    let asset: PhotoAsset
    let isKeep: Bool
    let onTapKeep: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let thumb = asset.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay { ProgressView() }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isKeep ? Color.green : Color.clear, lineWidth: 3)
            )

            if isKeep {
                Text("KEEP")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 6)
            }
        }
        .onTapGesture(perform: onTapKeep)
        .task { await asset.loadThumbnail() }
    }
}
