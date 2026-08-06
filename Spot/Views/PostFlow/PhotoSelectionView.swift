import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum GalleryPickMode: Equatable {
    case add
    case replace(UUID)
}

private struct RemovedPhoto {
    let photo: PostComposerPhoto
    let index: Int
}

struct PhotoSelectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var permissionManager: PermissionManager
    @Binding var selectedPhotos: [PostComposerPhoto]
    let draftCount: Int
    let onOpenDrafts: () -> Void
    var onFreeTierGalleryOverflow: (() -> Void)?

    @State private var activePhotoID: UUID?
    @State private var editorPhoto: PostComposerPhoto?
    @State private var galleryPickerItems: [PhotosPickerItem] = []
    @State private var galleryPickMode: GalleryPickMode = .add
    @State private var showGalleryPicker = false
    @State private var showAddSourceSheet = false
    @State private var showPhotoLibraryPrePrompt = false
    @State private var showCameraPrePrompt = false
    @State private var showCamera = false
    @State private var showPhotoSettingsAlert = false
    @State private var showCameraSettingsAlert = false
    @State private var showDeleteConfirmation = false
    @State private var showReplaceWarning = false
    @State private var isOpeningPicker = false
    @State private var isImporting = false
    @State private var importCount = 0
    @State private var errorMessage: String?
    @State private var retryGalleryMode: GalleryPickMode?
    @State private var removedPhoto: RemovedPhoto?
    @State private var undoTask: Task<Void, Never>?
    @State private var draggedPhotoID: UUID?

    var body: some View {
        VStack(spacing: 18) {
            header
            if selectedPhotos.isEmpty {
                emptyState
            } else {
                managementWorkspace
            }
            if isImporting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Adding \(importCount) photo\(importCount == 1 ? "" : "s")…")
                }
                .font(.caption)
                .foregroundStyle(Constants.Colors.primary)
                .accessibilityElement(children: .combine)
            }
            if permissionManager.photoStatus == .limited {
                Button("Manage Photo Access") {
                    permissionManager.openPhotoSettings()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Constants.Colors.primary)
                .frame(minHeight: 44)
                .accessibilityHint("Opens Settings to change which photos Spot can access")
            }
            if selectedPhotos.isEmpty {
                Text("Add at least one photo to continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 12)
        .accessibilityIdentifier("posting.photoStepRoot")
        .onAppear {
            permissionManager.updatePermissionStatuses()
            repairActiveSelection()
        }
        .onChange(of: selectedPhotos) { _, _ in repairActiveSelection() }
        .photosPicker(
            isPresented: $showGalleryPicker,
            selection: $galleryPickerItems,
            maxSelectionCount: galleryPickerMaxSelectionCount,
            matching: .images,
            preferredItemEncoding: .compatible
        )
        .onChange(of: showGalleryPicker) { _, presented in
            guard !presented else { return }
            isOpeningPicker = false
            if galleryPickerItems.isEmpty {
                AnalyticsService.shared.logEvent("spot_photo_picker_cancelled", parameters: [:])
            }
        }
        .onChange(of: galleryPickerItems) { _, items in
            guard !items.isEmpty else { return }
            let mode = galleryPickMode
            Task { await importPickerItems(items, mode: mode) }
        }
        .confirmationDialog("Add Photos", isPresented: $showAddSourceSheet, titleVisibility: .visible) {
            Button("Choose from Photos") { openGalleryAddIfPermitted() }
            Button("Take a Photo") { openCameraIfPermitted() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(remainingCapacityText)
        }
        .alert("Photo Library Access Is Off", isPresented: $showPhotoSettingsAlert) {
            Button("Open Settings") { permissionManager.openPhotoSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Photo access is needed to choose images for your Spot.")
        }
        .alert("Camera Access Is Off", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") { permissionManager.openCameraSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is needed to take a new photo.")
        }
        .alert("Remove this photo from your Spot?", isPresented: $showDeleteConfirmation) {
            Button("Keep Photo", role: .cancel) {}
            Button("Remove", role: .destructive) { removeActivePhoto() }
        }
        .alert("Replace Photo", isPresented: $showReplaceWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) { openGalleryReplaceIfPermitted() }
        } message: {
            Text("Replacing this photo will remove its current edits.")
        }
        .alert("Photo Error", isPresented: errorBinding) {
            if let retryGalleryMode {
                Button("Try Again") {
                    switch retryGalleryMode {
                    case .add: openGalleryAddIfPermitted()
                    case .replace: openGalleryReplaceIfPermitted()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "We couldn’t open your photo library. Please try again.")
        }
        .sheet(isPresented: $showPhotoLibraryPrePrompt) {
            PhotoPermissionView(
                authDestination: .signup,
                showsBackButton: false,
                onComplete: finishPhotoPermissionPrompt
            )
            .environmentObject(permissionManager)
        }
        .sheet(isPresented: $showCameraPrePrompt) {
            CameraPermissionView(
                authDestination: .signup,
                showsBackButton: false,
                onComplete: finishCameraPermissionPrompt
            )
            .environmentObject(permissionManager)
        }
        .sheet(isPresented: $showCamera) {
            SpotPhotoCameraView { result in
                showCamera = false
                handleCameraResult(result)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $editorPhoto) { photo in
            SpotPhotoEditorView(photo: photo) { edits in
                saveEdits(edits, for: photo.id)
            }
        }
        .overlay(alignment: .bottom) {
            if let removedPhoto {
                HStack {
                    Text("Photo removed")
                    Spacer()
                    Button("Undo") { undoRemoval(removedPhoto) }
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(Constants.Colors.buttonText)
                .padding()
                .background(Constants.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear {
            undoTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create a Spot")
                    .font(FontManager.sectionHeader())
                    .foregroundStyle(Constants.Colors.primary)
                Text("Start by adding photos of this place.")
                    .font(FontManager.primaryText())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onOpenDrafts) {
                VStack(spacing: 2) {
                    Text("Drafts").font(.caption.weight(.semibold))
                    Text("\(draftCount)").font(.caption2)
                }
                .foregroundStyle(Constants.Colors.primary)
                .frame(minWidth: 48, minHeight: 44)
                .padding(.horizontal, 6)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.primary))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("posting.draftsButton")
            .accessibilityLabel("Drafts, \(draftCount)")
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34))
                    .foregroundStyle(Constants.Colors.primary)
                Text("Add photos")
                    .font(FontManager.sectionHeader())
                    .foregroundStyle(Constants.Colors.primary)
                Text("Choose up to \(maxPhotoCount) photo\(maxPhotoCount == 1 ? "" : "s"). You can crop, rotate, and reorder them before posting.")
                    .font(FontManager.primaryText())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                primaryGalleryButton
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Constants.Colors.primary.opacity(0.15)))

            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)

            secondaryCameraButton(title: "Take a Photo")
        }
        .padding(.horizontal, 24)
    }

    private var primaryGalleryButton: some View {
        Button(action: openGalleryAddIfPermitted) {
            Label(isOpeningPicker ? "Opening Photos…" : "Choose Photos", systemImage: "photo.stack")
                .font(FontManager.buttonText())
                .foregroundStyle(Constants.Colors.buttonText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Constants.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
        }
        .buttonStyle(SpotPressedButtonStyle())
        .disabled(isOpeningPicker || isImporting)
        .accessibilityIdentifier("posting.choosePhotosButton")
        .accessibilityHint(remainingCapacityText)
    }

    private var managementWorkspace: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(activePhotoIndex + 1) of \(selectedPhotos.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Constants.Colors.primary)
                Spacer()
                Button("Edit") { openEditor() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Constants.Colors.primary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Edit photo \(activePhotoIndex + 1) of \(selectedPhotos.count)")
                Menu {
                    photoActionMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Photo actions")
            }
            .padding(.horizontal, 24)

            if let activePhoto {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.9)
                    Image(uiImage: activePhoto.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { openEditor() }
                        .accessibilityLabel("Edit photo \(activePhotoIndex + 1) of \(selectedPhotos.count)")
                        .accessibilityAddTraits(.isButton)
                    if activePhotoIndex == 0 {
                        coverBadge.padding(12)
                    }
                    if activePhoto.processingState == .processing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if activePhoto.processingState == .failed || activePhoto.processingState == .unavailable {
                        VStack(spacing: 10) {
                            Text(activePhoto.processingState == .unavailable
                                ? "This photo is no longer available on this device."
                                : "We couldn’t prepare this photo.")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                            HStack {
                                Button("Replace") { prepareReplacement() }
                                Button("Remove", role: .destructive) { requestDelete() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: activePreviewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            }

            Text("Hold and drag photos to reorder. The first photo is the cover.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            thumbnailTray

            if selectedPhotos.count < maxPhotoCount {
                secondaryCameraButton(title: "Take another photo")
                    .padding(.horizontal, 24)
            } else if selectedPhotos.count == maxPhotoCount {
                Text("Maximum of \(maxPhotoCount) photos reached.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Constants.Colors.primary)
            } else {
                Text("Remove \(selectedPhotos.count - maxPhotoCount) photo\(selectedPhotos.count - maxPhotoCount == 1 ? "" : "s") to continue.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var thumbnailTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                    thumbnail(photo, index: index)
                }
                if selectedPhotos.count < maxPhotoCount {
                    Button {
                        showAddSourceSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title3)
                            Text("Add").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Constants.Colors.primary)
                        .frame(width: 80, height: 80)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary.opacity(0.4)))
                    }
                    .buttonStyle(SpotPressedButtonStyle())
                    .accessibilityLabel("Add more photos")
                    .accessibilityHint(remainingCapacityText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 2)
        }
    }

    private func thumbnail(_ photo: PostComposerPhoto, index: Int) -> some View {
        Menu {
            Button("Edit Photo") {
                activePhotoID = photo.id
                openEditor()
            }
            if index > 0 {
                Button("Make Cover") { makeCover(photo.id) }
            }
            Button("Move Left") { move(photo.id, by: -1) }
                .disabled(index == 0)
            Button("Move Right") { move(photo.id, by: 1) }
                .disabled(index == selectedPhotos.count - 1)
            Button("Move to Start") { move(photo.id, to: 0) }
                .disabled(index == 0)
            Button("Move to End") { move(photo.id, to: selectedPhotos.count - 1) }
                .disabled(index == selectedPhotos.count - 1)
            Button("Remove Photo", role: .destructive) {
                activePhotoID = photo.id
                requestDelete()
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                if index == 0 {
                    Text("Cover")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Constants.Colors.buttonText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Constants.Colors.primary)
                        .clipShape(Capsule())
                        .padding(4)
                }
                if photo.processingState == .processing {
                    ProgressView().tint(.white).frame(width: 80, height: 80)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(photo.id == activePhotoID ? Constants.Colors.primary : .clear, lineWidth: 3)
            )
            .contentShape(Rectangle())
        } primaryAction: {
            activePhotoID = photo.id
        }
        .accessibilityLabel("Photo \(index + 1) of \(selectedPhotos.count)\(index == 0 ? ", cover photo" : "")")
        .accessibilityHint("Double tap to select. Actions include editing and reordering.")
        .draggable(photo.id.uuidString) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    draggedPhotoID = photo.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let sourceID = UUID(uuidString: raw),
                  let source = selectedPhotos.firstIndex(where: { $0.id == sourceID }) else { return false }
            move(sourceID, to: index)
            draggedPhotoID = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return source != index
        } isTargeted: { _ in }
    }

    @ViewBuilder
    private var photoActionMenu: some View {
        Button("Edit Photo") { openEditor() }
        if activePhotoIndex != 0 {
            Button("Make Cover") { makeActivePhotoCover() }
        }
        Button("Replace Photo") { prepareReplacement() }
        Button("Delete Photo", role: .destructive) { requestDelete() }
    }

    private var coverBadge: some View {
        Label("Cover", systemImage: "star.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Constants.Colors.buttonText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Constants.Colors.primary)
            .clipShape(Capsule())
    }

    private func secondaryCameraButton(title: String) -> some View {
        Button(action: openCameraIfPermitted) {
            Label(title, systemImage: "camera")
                .font(FontManager.primaryText())
                .foregroundStyle(Constants.Colors.primary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Constants.Colors.primary))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
        }
        .buttonStyle(SpotPressedButtonStyle())
        .disabled(selectedPhotos.count >= maxPhotoCount || showCamera)
        .accessibilityLabel(title)
    }
}

private extension PhotoSelectionView {
    var maxPhotoCount: Int {
        authVM.isPro ? Constants.PostLimits.maxProPostImages : Constants.PostLimits.maxFreePostImages
    }

    var remainingCapacityText: String {
        let remaining = max(0, maxPhotoCount - selectedPhotos.count)
        return remaining == 1 ? "You can add 1 more photo." : "You can add \(remaining) more photos."
    }

    var galleryPickerMaxSelectionCount: Int {
        switch galleryPickMode {
        case .add: max(1, maxPhotoCount - selectedPhotos.count)
        case .replace: 1
        }
    }

    var activePhotoIndex: Int {
        guard let activePhotoID,
              let index = selectedPhotos.firstIndex(where: { $0.id == activePhotoID }) else { return 0 }
        return index
    }

    var activePhoto: PostComposerPhoto? {
        guard selectedPhotos.indices.contains(activePhotoIndex) else { return nil }
        return selectedPhotos[activePhotoIndex]
    }

    var activePreviewHeight: CGFloat {
        guard let activePhoto else { return 300 }
        let ratio = activePhoto.image.size.width / max(activePhoto.image.size.height, 1)
        return min(390, max(230, (UIScreen.main.bounds.width - 48) / ratio))
    }

    var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                    retryGalleryMode = nil
                }
            }
        )
    }

    func repairActiveSelection() {
        guard !selectedPhotos.isEmpty else {
            activePhotoID = nil
            return
        }
        if activePhotoID == nil || !selectedPhotos.contains(where: { $0.id == activePhotoID }) {
            activePhotoID = selectedPhotos.first?.id
        }
    }

    func beginPickerPresentation(mode: GalleryPickMode) {
        guard !isOpeningPicker else { return }
        isOpeningPicker = true
        galleryPickMode = mode
        galleryPickerItems = []
        AnalyticsService.shared.logEvent("spot_photo_picker_opened", parameters: [
            "mode": mode == .add ? "add" : "replace",
            "remaining": max(0, maxPhotoCount - selectedPhotos.count)
        ])
        showGalleryPicker = true
    }

    func openGalleryAddIfPermitted() {
        guard selectedPhotos.count < maxPhotoCount else {
            errorMessage = "You can add up to \(maxPhotoCount) photos."
            return
        }
        guard !isOpeningPicker, !isImporting else { return }
        permissionManager.updatePermissionStatuses()
        switch permissionManager.photoStatus {
        case .authorized, .limited:
            beginPickerPresentation(mode: .add)
        case .notDetermined:
            galleryPickMode = .add
            showPhotoLibraryPrePrompt = true
        case .denied, .restricted:
            showPhotoSettingsAlert = true
            AnalyticsService.shared.logEvent("spot_photo_permission_denied", parameters: [:])
        @unknown default:
            showPhotoSettingsAlert = true
        }
    }

    func openGalleryReplaceIfPermitted() {
        guard let activePhotoID, !isOpeningPicker, !isImporting else { return }
        permissionManager.updatePermissionStatuses()
        switch permissionManager.photoStatus {
        case .authorized, .limited:
            beginPickerPresentation(mode: .replace(activePhotoID))
        case .notDetermined:
            galleryPickMode = .replace(activePhotoID)
            showPhotoLibraryPrePrompt = true
        case .denied, .restricted:
            showPhotoSettingsAlert = true
        @unknown default:
            showPhotoSettingsAlert = true
        }
    }

    func finishPhotoPermissionPrompt() {
        permissionManager.updatePermissionStatuses()
        showPhotoLibraryPrePrompt = false
        let status = permissionManager.photoStatus
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            switch status {
            case .authorized, .limited:
                beginPickerPresentation(mode: galleryPickMode)
            case .denied, .restricted:
                showPhotoSettingsAlert = true
            default:
                isOpeningPicker = false
            }
        }
    }

    func importPickerItems(_ items: [PhotosPickerItem], mode: GalleryPickMode) async {
        isImporting = true
        importCount = items.count
        defer {
            isImporting = false
            importCount = 0
            isOpeningPicker = false
            galleryPickerItems = []
        }

        var imported: [PostComposerPhoto] = []
        for item in items {
            do {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) &&
                    !item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) {
                    throw PostPhotoImportError.video
                }
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw PostPhotoImportError.unreadable
                }
                imported.append(try PostPhotoProcessor.importImage(data: data, source: .gallery))
            } catch {
                SpotLogger.log(PhotoSelectionViewLogs.loadPhotosFailed, details: [
                    "action": mode == .add ? "add" : "replace",
                    "permission": String(describing: permissionManager.photoStatus),
                    "platform": UIDevice.current.systemVersion,
                    "error": error.localizedDescription
                ])
                errorMessage = (error as? LocalizedError)?.errorDescription ??
                    "We couldn’t open your photo library. Please try again."
                retryGalleryMode = mode
            }
        }

        guard !imported.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            AnalyticsService.shared.logEvent("spot_photo_picker_failed", parameters: ["category": "import"])
            return
        }
        switch mode {
        case .add:
            let available = max(0, maxPhotoCount - selectedPhotos.count)
            let accepted = Array(imported.prefix(available))
            selectedPhotos.append(contentsOf: accepted)
            activePhotoID = accepted.first?.id
            if imported.count > available {
                errorMessage = "You can add up to \(maxPhotoCount) photos."
                AnalyticsService.shared.logEvent("spot_photo_max_reached", parameters: [:])
            }
            if !authVM.isPro, items.count > 1 {
                onFreeTierGalleryOverflow?()
            }
            AnalyticsService.shared.logEvent("spot_photos_added", parameters: [
                "count": accepted.count,
                "source": "gallery"
            ])
        case let .replace(photoID):
            guard let replacement = imported.first,
                  let index = selectedPhotos.firstIndex(where: { $0.id == photoID }) else { return }
            selectedPhotos[index] = PostComposerPhoto(
                id: photoID,
                image: replacement.image,
                originalImage: replacement.originalImage,
                source: .gallery
            )
            activePhotoID = photoID
            AnalyticsService.shared.logEvent("spot_photo_replaced", parameters: [:])
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SpotLogger.log(PhotoSelectionViewLogs.photosSelectedFromGallery, details: ["count": imported.count])
    }

    func openCameraIfPermitted() {
        guard selectedPhotos.count < maxPhotoCount else {
            errorMessage = "You can add up to \(maxPhotoCount) photos."
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "The camera isn’t available on this device."
            retryGalleryMode = nil
            return
        }
        permissionManager.updatePermissionStatuses()
        switch permissionManager.cameraStatus {
        case .authorized:
            showCamera = true
            AnalyticsService.shared.logEvent("spot_camera_opened", parameters: [:])
        case .notDetermined:
            showCameraPrePrompt = true
        case .denied, .restricted:
            showCameraSettingsAlert = true
            AnalyticsService.shared.logEvent("spot_photo_permission_denied", parameters: ["type": "camera"])
        @unknown default:
            showCameraSettingsAlert = true
        }
    }

    func finishCameraPermissionPrompt() {
        permissionManager.updatePermissionStatuses()
        showCameraPrePrompt = false
        let status = permissionManager.cameraStatus
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if status == .authorized {
                showCamera = true
            } else if status == .denied || status == .restricted {
                showCameraSettingsAlert = true
            }
        }
    }

    func handleCameraResult(_ result: Result<UIImage, Error>?) {
        guard let result else {
            AnalyticsService.shared.logEvent("spot_camera_cancelled", parameters: [:])
            return
        }
        do {
            let photo = try PostPhotoProcessor.importCameraImage(result.get())
            guard selectedPhotos.count < maxPhotoCount else { return }
            selectedPhotos.append(photo)
            activePhotoID = photo.id
            SpotLogger.log(PhotoSelectionViewLogs.photoCapturedWithCamera)
            AnalyticsService.shared.logEvent("spot_photo_captured", parameters: [:])
        } catch {
            SpotLogger.log(PhotoSelectionViewLogs.capturePhotoFailed, details: ["error": error.localizedDescription])
            errorMessage = "We couldn’t prepare this photo."
        }
    }

    func openEditor() {
        guard let activePhoto else { return }
        guard activePhoto.processingState != .unavailable else {
            errorMessage = "This photo is no longer available on this device."
            retryGalleryMode = nil
            return
        }
        editorPhoto = activePhoto
        AnalyticsService.shared.logEvent("spot_photo_edit_opened", parameters: [:])
    }

    func saveEdits(_ edits: PostComposerPhotoEdits, for photoID: UUID) {
        guard let index = selectedPhotos.firstIndex(where: { $0.id == photoID }) else { return }
        let original = selectedPhotos[index].originalImage
        let revision = UUID()
        selectedPhotos[index].edits = edits
        selectedPhotos[index].processingState = .processing
        selectedPhotos[index].processingError = nil
        selectedPhotos[index].renderRevision = revision
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try PostPhotoProcessor.render(original: original, edits: edits) }
            }.value
            guard let currentIndex = selectedPhotos.firstIndex(where: { $0.id == photoID }),
                  selectedPhotos[currentIndex].renderRevision == revision else { return }
            switch result {
            case let .success(image):
                selectedPhotos[currentIndex].image = image
                selectedPhotos[currentIndex].processingState = .ready
            case let .failure(error):
                selectedPhotos[currentIndex].processingState = .failed
                selectedPhotos[currentIndex].processingError = error.localizedDescription
                errorMessage = "We couldn’t prepare this photo."
                AnalyticsService.shared.logEvent("spot_photo_processing_failed", parameters: [:])
            }
        }
    }

    func prepareReplacement() {
        guard let activePhoto else { return }
        if activePhoto.edits.isNeutral {
            openGalleryReplaceIfPermitted()
        } else {
            showReplaceWarning = true
        }
    }

    func requestDelete() {
        if selectedPhotos.count == 1 {
            showDeleteConfirmation = true
        } else {
            removeActivePhoto()
        }
    }

    func removeActivePhoto() {
        guard selectedPhotos.indices.contains(activePhotoIndex) else { return }
        let index = activePhotoIndex
        let photo = selectedPhotos.remove(at: index)
        activePhotoID = selectedPhotos.isEmpty ? nil : selectedPhotos[min(index, selectedPhotos.count - 1)].id
        removedPhoto = RemovedPhoto(photo: photo, index: index)
        AnalyticsService.shared.logEvent("spot_photo_removed", parameters: ["wasCover": index == 0])
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut) { removedPhoto = nil }
        }
    }

    func undoRemoval(_ removal: RemovedPhoto) {
        undoTask?.cancel()
        let index = min(removal.index, selectedPhotos.count)
        selectedPhotos.insert(removal.photo, at: index)
        activePhotoID = removal.photo.id
        removedPhoto = nil
    }

    func makeActivePhotoCover() {
        guard let activePhotoID else { return }
        makeCover(activePhotoID)
    }

    func makeCover(_ id: UUID) {
        selectedPhotos = PostComposerPhotoOperations.makingCover(selectedPhotos, id: id)
        activePhotoID = id
        AnalyticsService.shared.logEvent("spot_photo_made_cover", parameters: [:])
    }

    func move(_ id: UUID, by offset: Int) {
        guard let source = selectedPhotos.firstIndex(where: { $0.id == id }) else { return }
        move(id, to: min(max(0, source + offset), selectedPhotos.count - 1))
    }

    func move(_ id: UUID, to destination: Int) {
        guard let source = selectedPhotos.firstIndex(where: { $0.id == id }) else { return }
        selectedPhotos = PostComposerPhotoOperations.reordered(selectedPhotos, from: source, to: destination)
        activePhotoID = id
        AnalyticsService.shared.logEvent("spot_photo_reordered", parameters: [
            "from": source,
            "to": destination
        ])
    }
}

private struct SpotPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SpotPhotoCameraView: UIViewControllerRepresentable {
    let onComplete: (Result<UIImage, Error>?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onComplete: (Result<UIImage, Error>?) -> Void

        init(onComplete: @escaping (Result<UIImage, Error>?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard (info[.mediaType] as? String).map({ UTType($0)?.conforms(to: .image) == true }) ?? true,
                  let image = info[.originalImage] as? UIImage else {
                onComplete(.failure(PostPhotoImportError.video))
                return
            }
            onComplete(.success(image))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            SpotLogger.log(PhotoSelectionViewLogs.cameraCancelled)
            onComplete(nil)
        }
    }
}

#Preview {
    PhotoSelectionPreviewHost()
}

private struct PhotoSelectionPreviewHost: View {
    @State private var photos: [PostComposerPhoto] = []
    @StateObject private var authVM: AuthViewModel

    init() {
        let vm = AuthViewModel()
        vm.isPro = true
        _authVM = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ScrollView {
            PhotoSelectionView(
                selectedPhotos: $photos,
                draftCount: 2,
                onOpenDrafts: {}
            )
        }
        .background(Constants.Colors.background)
        .environmentObject(authVM)
        .environmentObject(PermissionManager.shared)
    }
}
