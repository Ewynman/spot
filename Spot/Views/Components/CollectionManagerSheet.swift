import SwiftUI

struct CollectionManagerSheet: View {
    let spotId: String
    var onDone: () -> Void
    var onMembershipChange: (Int) -> Void

    @State private var collections: [BookmarkCollection] = []
    @State private var selectedIds: Set<String> = []
    @State private var mutatingIds: Set<String> = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var showsCreateCollection = false
    @State private var newCollectionName = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Constants.Colors.primary.opacity(0.22))
                    .frame(width: 42, height: 5)
                    .padding(.top, Constants.Layout.Spacing.small)

                HStack {
                    Text(showsCreateCollection ? "New collection" : "Add to collection")
                        .font(FontManager.sectionHeader())
                        .foregroundColor(Constants.Colors.primary)
                    Spacer()
                    Button("Done", action: onDone)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("collectionManager.done")
                }
                .padding(Constants.Layout.Spacing.large)

                if showsCreateCollection {
                    createCollectionContent
                } else {
                    collectionListContent
                }
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                ToastView(message: errorMessage, isError: true)
                    .padding(.top, Constants.Layout.Spacing.small)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await load() }
        .presentationBackground(Constants.Colors.background)
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("collectionManager.sheet")
    }

    @ViewBuilder
    private var collectionListContent: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .tint(Constants.Colors.primary)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: Constants.Layout.Spacing.small) {
                    if collections.isEmpty {
                        Text("No collections yet")
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary.opacity(0.62))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Constants.Layout.Spacing.extraLarge)
                    }

                    ForEach(collections) { collection in
                        collectionRow(collection)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsCreateCollection = true
                        }
                    } label: {
                        HStack(spacing: Constants.Layout.Spacing.small) {
                            Image(systemName: "plus")
                            Text("New collection")
                                .font(FontManager.primaryText())
                            Spacer()
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.horizontal, Constants.Layout.Spacing.large)
                        .padding(.vertical, Constants.Layout.Spacing.medium)
                        .background(Constants.Colors.accent.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collectionManager.newCollection")
                }
                .padding(.horizontal, Constants.Layout.Spacing.large)
                .padding(.bottom, Constants.Layout.Spacing.large)
            }
        }
    }

    private func collectionRow(_ collection: BookmarkCollection) -> some View {
        let isSelected = selectedIds.contains(collection.id)
        let isMutating = mutatingIds.contains(collection.id)

        return Button {
            guard !isMutating else { return }
            toggle(collection)
        } label: {
            HStack(spacing: Constants.Layout.Spacing.medium) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Constants.Colors.primary : Constants.Colors.accent)
                        .frame(width: 28, height: 28)
                    if isMutating {
                        ProgressView()
                            .tint(isSelected ? Constants.Colors.buttonText : Constants.Colors.primary)
                            .scaleEffect(0.65)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Constants.Colors.buttonText)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(collection.name)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                    Text("\(collection.spotIds.count) \(collection.spotIds.count == 1 ? "spot" : "spots")")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.primary.opacity(0.58))
                }
                Spacer()
            }
            .padding(.horizontal, Constants.Layout.Spacing.large)
            .padding(.vertical, Constants.Layout.Spacing.medium)
            .background(isSelected ? Constants.Colors.accent : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                    .stroke(Constants.Colors.primary.opacity(isSelected ? 0.32 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isMutating)
        .accessibilityLabel(collection.name)
        .accessibilityValue(isSelected ? "Selected, \(collection.spotIds.count) spots" : "Not selected, \(collection.spotIds.count) spots")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("collectionManager.collection.\(collection.id)")
    }

    @ViewBuilder
    private var createCollectionContent: some View {
        VStack(spacing: Constants.Layout.Spacing.large) {
            TextField("Collection name", text: $newCollectionName)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .padding(Constants.Layout.Spacing.medium)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                        .stroke(Constants.Colors.primary.opacity(0.3), lineWidth: 1)
                }
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { createCollection() }
                .accessibilityIdentifier("collectionManager.nameField")

            HStack(spacing: Constants.Layout.Spacing.medium) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsCreateCollection = false
                        newCollectionName = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Constants.Layout.Spacing.medium)
                        .background(Constants.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                }
                .buttonStyle(.plain)

                Button(action: createCollection) {
                    Group {
                        if isCreating {
                            ProgressView().tint(Constants.Colors.buttonText)
                        } else {
                            Text("Create Collection")
                                .font(FontManager.buttonText())
                        }
                    }
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Layout.Spacing.medium)
                    .background(Constants.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                }
                .buttonStyle(.plain)
                .disabled(!CollectionNamePolicy.canCreate(newCollectionName) || isCreating)
                .opacity(CollectionNamePolicy.canCreate(newCollectionName) ? 1 : 0.5)
                .accessibilityIdentifier("collectionManager.create")
            }
        }
        .padding(.horizontal, Constants.Layout.Spacing.large)

        Spacer(minLength: Constants.Layout.Spacing.large)
    }

    @MainActor
    private func load() async {
        isLoading = true
        do {
            let loaded = try await BookmarksCollectionsService.shared.listCollections()
            collections = loaded
            selectedIds = Set(
                loaded
                    .filter { $0.spotIds.contains(spotId) }
                    .map(\.id)
            )
            onMembershipChange(selectedIds.count)
        } catch {
            showError("Couldn't load collections")
        }
        isLoading = false
    }

    private func toggle(_ collection: BookmarkCollection) {
        let wasSelected = selectedIds.contains(collection.id)
        if wasSelected {
            selectedIds.remove(collection.id)
        } else {
            selectedIds.insert(collection.id)
        }
        updateLocalMembership(collectionId: collection.id, isSelected: !wasSelected)
        mutatingIds.insert(collection.id)
        onMembershipChange(selectedIds.count)

        Task { @MainActor in
            do {
                if wasSelected {
                    try await BookmarksCollectionsService.shared.removeSpot(spotId, from: collection.id)
                } else {
                    try await BookmarksCollectionsService.shared.addSpot(spotId, to: collection.id)
                }
            } catch {
                if wasSelected {
                    selectedIds.insert(collection.id)
                } else {
                    selectedIds.remove(collection.id)
                }
                updateLocalMembership(collectionId: collection.id, isSelected: wasSelected)
                onMembershipChange(selectedIds.count)
                showError("Couldn't update collection")
            }
            mutatingIds.remove(collection.id)
        }
    }

    private func updateLocalMembership(collectionId: String, isSelected: Bool) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        if isSelected {
            if !collections[index].spotIds.contains(spotId) {
                collections[index].spotIds.append(spotId)
            }
        } else {
            collections[index].spotIds.removeAll { $0 == spotId }
        }
    }

    private func createCollection() {
        let name = CollectionNamePolicy.normalized(newCollectionName)
        guard CollectionNamePolicy.canCreate(name), !isCreating else { return }
        isCreating = true

        Task { @MainActor in
            do {
                let collectionId = try await BookmarksCollectionsService.shared.createCollection(name: name)
                try await BookmarksCollectionsService.shared.addSpot(spotId, to: collectionId)
                newCollectionName = ""
                showsCreateCollection = false
                await load()
            } catch {
                showError("Couldn't create collection")
            }
            isCreating = false
        }
    }

    private func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            errorMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                if errorMessage == message {
                    errorMessage = nil
                }
            }
        }
    }
}

#Preview {
    CollectionManagerSheet(spotId: UUID().uuidString, onDone: {}, onMembershipChange: { _ in })
        .presentationDetents([.medium])
}
