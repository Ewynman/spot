//
//  EditSpotView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct EditSpotView: View {
    let onSaved: ((Spot) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel: EditSpotViewModel

    @State private var activePhotoID: UUID?
    @State private var pendingDeletePhotoID: UUID?
    @State private var replacementTargetID: UUID?
    @State private var replacementPickerItem: PhotosPickerItem?
    @State private var draggedPhotoID: UUID?
    @State private var showDiscardConfirmation = false
    @State private var showLocationPicker = false
    @State private var locationDraft: LocationData?

    init(spot: Spot, onSaved: ((Spot) -> Void)? = nil) {
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: EditSpotViewModel(spot: spot))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Group {
                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.photos.isEmpty {
                        loadFailureState
                    } else {
                        editorContent
                    }
                }
            }
            .background(Constants.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.isLoading, !viewModel.photos.isEmpty {
                    saveBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                viewModel.setIsPro(authVM.isPro)
                await viewModel.load()
            }
            .onChange(of: authVM.isPro) { _, isPro in
                viewModel.setIsPro(isPro)
            }
            .sheet(isPresented: $showLocationPicker) {
                locationPicker
            }
            .interactiveDismissDisabled(viewModel.isDirty || viewModel.isSaving)
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    ToastView(message: error, isError: true)
                        .padding(.top, Constants.Layout.Spacing.small)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { viewModel.errorMessage = nil }
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .overlay {
                if activePhotoID != nil {
                    photoActionsOverlay
                        .transition(.opacity)
                } else if pendingDeletePhotoID != nil {
                    deleteConfirmation
                        .transition(.opacity)
                } else if showDiscardConfirmation {
                    discardConfirmation
                        .transition(.opacity)
                }
            }
            .onChange(of: replacementPickerItem) { _, item in
                guard let item, let targetID = replacementTargetID else { return }
                Task { @MainActor in
                    await importReplacement(item, for: targetID)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        ZStack {
            Text("Edit Spot")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)

            HStack {
                CustomBackButton(action: close)
                    .accessibilityLabel("Close Edit Spot")
                Spacer()
            }
        }
        .frame(height: 52)
        .padding(.horizontal, Constants.Layout.Padding.horizontal)
        .background(Constants.Colors.background)
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Layout.Spacing.extraLarge) {
                photosSection
                vibePhotoMappingSection
                vibesSection
                locationSection
            }
            .padding(.horizontal, Constants.Layout.Padding.horizontal)
            .padding(.top, Constants.Layout.Spacing.extraLarge)
            .padding(.bottom, Constants.Layout.Spacing.extraLarge)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            sectionHeader(title: "Photos", detail: photoCountText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Constants.Layout.Spacing.medium),
                    GridItem(.flexible(), spacing: Constants.Layout.Spacing.medium)
                ],
                spacing: Constants.Layout.Spacing.medium
            ) {
                ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                    photoTile(photo, index: index)
                }
            }

            Text("Drag to reorder. The first photo is the cover.")
                .font(.caption)
                .foregroundColor(Constants.Colors.welcomeMutedText)
                .accessibilityIdentifier("editSpot.photoReorderHint")
        }
        .accessibilityIdentifier("editSpot.photosSection")
    }

    private var vibePhotoMappingSection: some View {
        VibePhotoMappingSection(
            photos: viewModel.photos.map { photo in
                if let replacement = photo.replacement {
                    return (id: photo.id, thumbnail: Image(uiImage: replacement.image))
                }
                return (id: photo.id, thumbnail: Image(systemName: "photo"))
            },
            selectedVibes: viewModel.selectedVibes,
            canMatch: viewModel.canMatchVibesToPhotos,
            matchEnabled: Binding(
                get: { viewModel.matchVibesToPhotos },
                set: { viewModel.setMatchVibesToPhotos($0) }
            ),
            mappings: viewModel.vibePhotoMappings,
            statusMessage: viewModel.vibeMappingStatusMessage,
            onToggle: { viewModel.setMatchVibesToPhotos($0) },
            onAssign: { id, vibe in viewModel.assignVibe(vibe, toPhotoId: id) }
        )
        .padding(.horizontal, -Constants.Layout.Padding.horizontal)
    }

    private func photoTile(_ photo: EditSpotDraftPhoto, index: Int) -> some View {
        Button {
            guard !viewModel.isSaving else { return }
            activePhotoID = photo.id
        } label: {
            ZStack(alignment: .topTrailing) {
                photoContent(photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 32, height: 32)
                    .background(Constants.Colors.background.opacity(0.94))
                    .clipShape(Circle())
                    .padding(Constants.Layout.Spacing.small)

                if index == 0 {
                    Text("Cover")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, Constants.Layout.Spacing.small)
                        .padding(.vertical, 5)
                        .background(Constants.Colors.primary)
                        .clipShape(Capsule())
                        .padding(Constants.Layout.Spacing.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .accessibilityLabel("Cover photo")
                }
            }
            .background(Constants.Colors.welcomeSurface)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                    .stroke(Constants.Colors.primary.opacity(0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SpotPressedButtonStyle())
        .disabled(viewModel.isSaving)
        .accessibilityLabel(
            "Photo \(index + 1) of \(viewModel.photos.count)\(index == 0 ? ", cover photo" : "")"
        )
        .accessibilityHint("Double tap for Replace and Delete actions. Drag to reorder.")
        .draggable(photo.id.uuidString) {
            RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                .fill(Constants.Colors.accent)
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(Constants.Colors.primary)
                }
                .onAppear {
                    draggedPhotoID = photo.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let rawID = items.first,
                  let sourceID = UUID(uuidString: rawID) else { return false }
            viewModel.movePhoto(id: sourceID, to: index)
            draggedPhotoID = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return true
        } isTargeted: { _ in }
    }

    @ViewBuilder
    private func photoContent(_ photo: EditSpotDraftPhoto) -> some View {
        if let replacement = photo.replacement {
            Image(uiImage: replacement.image)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: photo.remoteURL) {
            RemoteImage(url: url, maxPixelSize: 900, transaction: Transaction(animation: .default)) { phase in
                switch phase {
                case .empty:
                    photoPlaceholder(showsProgress: true)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    photoPlaceholder(showsProgress: false)
                @unknown default:
                    photoPlaceholder(showsProgress: false)
                }
            }
        } else {
            photoPlaceholder(showsProgress: false)
        }
    }

    private func photoPlaceholder(showsProgress: Bool) -> some View {
        ZStack {
            Constants.Colors.accent
            if showsProgress {
                ProgressView().tint(Constants.Colors.primary)
            } else {
                Image("image_placeholder")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private var vibesSection: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            sectionHeader(
                title: "Vibes",
                detail: "\(viewModel.selectedVibes.count)/\(maximumVibes)"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Constants.Layout.Spacing.medium),
                    GridItem(.flexible(), spacing: Constants.Layout.Spacing.medium)
                ],
                spacing: Constants.Layout.Spacing.medium
            ) {
                ForEach(availableVibes, id: \.self) { vibe in
                    VibeTagButton(
                        vibe: vibe,
                        isSelected: viewModel.selectedVibes.contains(vibe),
                        onTap: {
                            _ = viewModel.toggleVibe(vibe, maximum: maximumVibes)
                        }
                    )
                    .disabled(viewModel.isSaving)
                    .accessibilityAddTraits(
                        viewModel.selectedVibes.contains(vibe) ? .isSelected : []
                    )
                    .accessibilityIdentifier("editSpot.vibe.\(vibe)")
                }
            }
        }
        .accessibilityIdentifier("editSpot.vibesSection")
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            sectionHeader(title: "Location", detail: nil)

            Button {
                guard !viewModel.isSaving else { return }
                locationDraft = viewModel.selectedLocation
                showLocationPicker = true
            } label: {
                HStack(spacing: Constants.Layout.Spacing.medium) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)

                    Text(locationDisplayName)
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.primary)
                        .lineLimit(2)

                    Spacer(minLength: Constants.Layout.Spacing.small)

                    Text(viewModel.selectedLocation == nil ? "Select" : "Change")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .padding(Constants.Layout.Padding.verticalLarge)
                .frame(minHeight: 58)
                .background(Constants.Colors.welcomeSurface)
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                        .stroke(Constants.Colors.primary.opacity(0.18), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SpotPressedButtonStyle())
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Location, \(locationDisplayName)")
            .accessibilityHint("Double tap to change the Spot location")
            .accessibilityIdentifier("editSpot.location")
        }
    }

    private func sectionHeader(title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Constants.Colors.welcomeMutedText)
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Constants.Colors.welcomeLine.opacity(0.35))
                .frame(height: 1)

            AuthPrimaryButton(
                title: viewModel.isSaving ? "Saving Changes" : "Save Changes",
                isLoading: viewModel.isSaving,
                isEnabled: canSave,
                action: save
            )
            .accessibilityIdentifier("editSpot.saveChanges")
            .accessibilityHint(canSave ? "Saves your edits" : "Make a change before saving")
            .padding(.horizontal, Constants.Layout.Padding.horizontal)
            .padding(.vertical, Constants.Layout.Padding.verticalMedium)
        }
        .background(Constants.Colors.background)
    }

    private var loadingState: some View {
        VStack(spacing: Constants.Layout.Spacing.medium) {
            ProgressView()
                .tint(Constants.Colors.primary)
            Text("Loading Spot…")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.welcomeMutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("editSpot.loading")
    }

    private var loadFailureState: some View {
        VStack(spacing: Constants.Layout.Spacing.large) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
            Text("We couldn’t load this Spot’s photos.")
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.center)
            AuthSecondaryButton(title: "Try Again") {
                Task { @MainActor in
                    await viewModel.load()
                }
            }
            .frame(maxWidth: 220)
        }
        .padding(Constants.Layout.Padding.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoActionsOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { activePhotoID = nil }

            VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
                Text("Edit Photo")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)

                PhotosPicker(
                    selection: $replacementPickerItem,
                    matching: .images,
                    preferredItemEncoding: .compatible
                ) {
                    actionRow(title: "Replace", systemImage: "photo.on.rectangle")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    replacementTargetID = activePhotoID
                })
                .accessibilityLabel(replaceAccessibilityLabel)

                Button {
                    pendingDeletePhotoID = activePhotoID
                    activePhotoID = nil
                } label: {
                    actionRow(title: "Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deleteAccessibilityLabel)

                Button("Cancel") { activePhotoID = nil }
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Constants.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
                    .buttonStyle(.plain)
            }
            .padding(Constants.Layout.Padding.verticalLarge)
            .background(Constants.Colors.background)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: Constants.Layout.CornerRadius.large,
                    topTrailingRadius: Constants.Layout.CornerRadius.large
                )
            )
            .shadow(color: Constants.Colors.welcomeCardShadow, radius: 16, y: -4)
        }
        .accessibilityIdentifier("editSpot.photoActions")
    }

    private func actionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: Constants.Layout.Spacing.medium) {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
                .font(FontManager.primaryText())
            Spacer()
        }
        .foregroundColor(Constants.Colors.primary)
        .padding(.horizontal, Constants.Layout.Padding.verticalLarge)
        .frame(minHeight: 52)
        .background(Constants.Colors.welcomeSurface)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.medium)
                .stroke(Constants.Colors.primary.opacity(0.14), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var deleteConfirmation: some View {
        CustomConfirmationDialog(
            title: "Delete photo?",
            message: "This photo will be removed from the Spot.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel",
            onConfirm: {
                if let id = pendingDeletePhotoID {
                    _ = viewModel.deletePhoto(id: id)
                }
                pendingDeletePhotoID = nil
            },
            onCancel: { pendingDeletePhotoID = nil }
        )
    }

    private var discardConfirmation: some View {
        CustomConfirmationDialog(
            title: "Discard changes?",
            message: "Your edits haven’t been saved.",
            confirmTitle: "Discard",
            cancelTitle: "Keep Editing",
            onConfirm: {
                showDiscardConfirmation = false
                dismiss()
            },
            onCancel: { showDiscardConfirmation = false }
        )
    }

    private var locationPicker: some View {
        NavigationStack {
            ScrollView {
                LocationSelectionView(
                    selectedLocation: $locationDraft,
                    onLocationConfirmed: { location in
                        viewModel.selectLocation(location)
                        showLocationPicker = false
                    }
                )
                    .padding(.top, Constants.Layout.Spacing.small)
            }
            .background(Constants.Colors.background.ignoresSafeArea())
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Constants.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CustomBackButton { showLocationPicker = false }
                        .accessibilityLabel("Close location picker")
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var maximumVibes: Int {
        min(
            Constants.PostLimits.maxProPostVibes,
            max(
                authVM.isPro
                    ? Constants.PostLimits.maxProPostVibes
                    : Constants.PostLimits.maxFreePostVibes,
                viewModel.initialVibeCount
            )
        )
    }

    private var availableVibes: [String] {
        var seen = Set<String>()
        return (
            viewModel.selectedVibes
                + authVM.customVibeTags
                + Constants.VibeTags.defaultTags
        )
        .filter { seen.insert($0).inserted }
    }

    private var canSave: Bool {
        viewModel.isDirty
            && !viewModel.isSaving
            && !viewModel.photos.isEmpty
            && !viewModel.selectedVibes.isEmpty
            && viewModel.selectedLocation != nil
    }

    private var photoCountText: String {
        "\(viewModel.photos.count) photo\(viewModel.photos.count == 1 ? "" : "s")"
    }

    private var locationDisplayName: String {
        let name = viewModel.selectedLocation?.placeName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "No location selected" : name
    }

    private var activePhotoNumber: Int? {
        guard let activePhotoID,
              let index = viewModel.photos.firstIndex(where: { $0.id == activePhotoID }) else {
            return nil
        }
        return index + 1
    }

    private var replaceAccessibilityLabel: String {
        "Replace photo \(activePhotoNumber ?? 1)"
    }

    private var deleteAccessibilityLabel: String {
        "Delete photo \(activePhotoNumber ?? 1)"
    }

    private func close() {
        guard !viewModel.isSaving else { return }
        if viewModel.isDirty {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        Task { @MainActor in
            if let updated = await viewModel.save(userId: authVM.userId) {
                onSaved?(updated)
                NotificationCenter.default.post(name: .spotDidUpdate, object: updated)
                dismiss()
            }
        }
    }

    @MainActor
    private func importReplacement(_ item: PhotosPickerItem, for targetID: UUID) async {
        defer {
            replacementPickerItem = nil
            replacementTargetID = nil
            activePhotoID = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PostPhotoImportError.unreadable
            }
            let photo = try PostPhotoProcessor.importImage(data: data, source: .gallery)
            viewModel.replacePhoto(id: targetID, with: photo)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            viewModel.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "We couldn’t open this photo. Please try another."
        }
    }
}

#Preview {
    let sample = Spot(
        id: "82d33f8c-74d7-4ae3-b22e-25f294885b82",
        userId: "56efcfad-c5cf-4eef-943b-ef4044f2b68f",
        username: "eddie",
        imageURL: "https://picsum.photos/seed/edit-cover/800/800",
        vibeTag: "Hidden Gem",
        vibeTags: ["Hidden Gem", "Scenic View", "Quiet Moment"],
        latitude: 47.4582,
        longitude: 8.5555,
        locationName: "Zurich Airport",
        createdAt: Date(),
        imageURLs: [
            "https://picsum.photos/seed/edit-a/800/800",
            "https://picsum.photos/seed/edit-b/800/800",
            "https://picsum.photos/seed/edit-c/800/800",
            "https://picsum.photos/seed/edit-d/800/800",
            "https://picsum.photos/seed/edit-e/800/800"
        ]
    )
    let auth = AuthViewModel()
    auth.isPro = true
    auth.userId = sample.userId
    return EditSpotView(spot: sample)
        .environmentObject(auth)
}
