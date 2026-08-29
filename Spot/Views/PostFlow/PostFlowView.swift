//
//  PostFlowView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import CoreLocation

struct PostFlowView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var viewModel = PostFlowViewModel()
    @AppStorage("hasAcceptedPostingRules") private var hasAcceptedPostingRules: Bool = false
    @State private var showRulesSheet: Bool = false
    @State private var isVerifyingEmail: Bool = true
    @State private var showVerifyEmailAlert: Bool = false
    @State private var showConfirmEmailSheet: Bool = false
    @State private var showDraftsSheet: Bool = false

    /// Fires on the main thread right after the publish pipeline accepts the draft (composer resets; use to e.g. switch tabs).
    var onPostQueued: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    if isVerifyingEmail {
                        ZStack {
                            Constants.Colors.background
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Constants.Colors.primary)
                                .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !authVM.isEmailVerified {
                        VStack(spacing: 0) {
                            Spacer()
                            VStack(spacing: 16) {
                                Text("Verify your email to post")
                                    .font(FontManager.sectionHeader())
                                    .foregroundColor(Constants.Colors.primary)
                                    .multilineTextAlignment(.center)
                                Text("We sent a link to your inbox. After you verify, tap \"I've verified\" on the next screen.")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Button(action: { showConfirmEmailSheet = true }) {
                                    Text("Open verification")
                                        .font(FontManager.buttonText())
                                        .foregroundColor(Constants.Colors.buttonText)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Constants.Colors.primary)
                                        .cornerRadius(20)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 24)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressIndicatorView(currentStep: viewModel.currentStep, totalSteps: viewModel.totalSteps)

                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                Color.clear.frame(height: 0).id("postFlowScrollTop")
                                Group {
                                    switch viewModel.currentStep {
                                    case 1:
                                        PhotoSelectionView(
                                            selectedPhotos: $viewModel.selectedPhotos,
                                            draftCount: viewModel.availableDrafts.count,
                                            onOpenDrafts: {
                                                showDraftsSheet = true
                                                viewModel.refreshDrafts()
                                            },
                                            onFreeTierGalleryOverflow: {
                                                viewModel.showToastWith(
                                                    message: Constants.PostLimits.freeMultipleImagesMessage,
                                                    isError: false
                                                )
                                            }
                                        )
                                    case 2:
                                        LocationSelectionView(selectedLocation: $viewModel.selectedLocation)
                                    case 3:
                                        VibeSelectionView(
                                            selectedVibes: $viewModel.selectedVibes,
                                            maxVibes: authVM.isPro
                                                ? Constants.PostLimits.maxProPostVibes
                                                : Constants.PostLimits.maxFreePostVibes,
                                            mappingPhotos: viewModel.selectedPhotos.map {
                                                (id: $0.id, thumbnail: Image(uiImage: $0.image))
                                            },
                                            canMatchVibesToPhotos: viewModel.canMatchVibesToPhotos,
                                            matchVibesToPhotos: $viewModel.matchVibesToPhotos,
                                            vibePhotoMappings: viewModel.vibePhotoMappings,
                                            vibeMappingStatusMessage: viewModel.vibeMappingStatusMessage,
                                            onMatchToggle: { viewModel.setMatchVibesToPhotos($0) },
                                            onAssignVibe: { id, vibe in viewModel.assignVibe(vibe, toPhotoId: id) },
                                            onVibesChanged: { viewModel.reconcileVibePhotoMappings() }
                                        )
                                    default:
                                        EmptyView()
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                            .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
                                guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 2 else { return }
                                guard !isVerifyingEmail, authVM.isEmailVerified else { return }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("postFlowScrollTop", anchor: .top)
                                }
                            }
                        }

                        NavigationButtonsView(
                            currentStep: $viewModel.currentStep,
                            totalSteps: viewModel.totalSteps,
                            canProceed: viewModel.currentStep == viewModel.totalSteps
                                ? viewModel.canSubmitPost && !viewModel.isEncodingPost
                                : viewModel.canProceedToNextStep && !viewModel.isEncodingPost,
                            canSaveDraft: viewModel.canSaveDraft && !viewModel.isEncodingPost,
                            isBusy: viewModel.isEncodingPost,
                            onBack: { viewModel.goBack() },
                            onNext: { viewModel.goNext() },
                            onFinish: { viewModel.submitPost() },
                            onSaveDraft: {
                                if viewModel.saveDraftManually() {
                                    onPostQueued?()
                                    dismiss()
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 8) {
                    if viewModel.showToast {
                        ToastView(message: viewModel.toastMessage, isError: viewModel.toastIsError)
                            .transition(.move(edge: .top))
                    }
                    if viewModel.showSuccessBanner {
                        SuccessToastView(message: "Spot posted!")
                            .transition(.move(edge: .top))
                    }
                }
                .padding(.top, 8)
            }
            .background(Constants.Colors.background.ignoresSafeArea())
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.light)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                CustomBackButton {
                    dismiss()
                }
            }
        }
        .task {
            viewModel.authViewModel = authVM
            viewModel.onPostQueued = onPostQueued
            _ = viewModel.loadPersistedDraftIfAvailable()
            viewModel.refreshDrafts()
            isVerifyingEmail = true
            _ = await authVM.checkVerificationStatus()
            isVerifyingEmail = false
            if authVM.isEmailVerified {
                showRulesIfNeeded()
            } else {
                showVerifyEmailAlert = true
            }
        }
        .onChange(of: authVM.isEmailVerified) { _, newValue in
            if newValue {
                showVerifyEmailAlert = false
                showRulesIfNeeded()
            }
        }
        .onChange(of: authVM.isPro) { _, isPro in
            if !isPro {
                if viewModel.selectedPhotos.count > Constants.PostLimits.maxFreePostImages {
                    viewModel.selectedPhotos = Array(viewModel.selectedPhotos.prefix(Constants.PostLimits.maxFreePostImages))
                }
                if viewModel.selectedVibes.count > Constants.PostLimits.maxFreePostVibes {
                    viewModel.selectedVibes = Array(viewModel.selectedVibes.prefix(Constants.PostLimits.maxFreePostVibes))
                }
            }
            viewModel.reconcileVibePhotoMappings()
        }
        .onChange(of: viewModel.selectedPhotos) { _, _ in
            viewModel.reconcileVibePhotoMappings()
            viewModel.persistDraftSnapshot()
        }
        .onChange(of: viewModel.selectedLocation) { _, _ in
            viewModel.persistDraftSnapshot()
        }
        .onChange(of: viewModel.selectedVibe) { _, _ in
            viewModel.persistDraftSnapshot()
        }
        .onChange(of: viewModel.selectedVibes) { _, vibes in
            viewModel.selectedVibe = vibes.first ?? ""
            viewModel.persistDraftSnapshot()
        }
        .onChange(of: viewModel.currentStep) { _, _ in
            viewModel.persistDraftSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidPostSuccess)) { _ in
            viewModel.clearPersistedDraft()
        }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidPostFailed)) { _ in
            viewModel.handlePublishFailure()
        }
        .alert("Verify your email", isPresented: $showVerifyEmailAlert) {
            Button("Open verification") {
                showConfirmEmailSheet = true
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You need a verified email to post. Check your inbox for the link we sent you.")
        }
        .sheet(isPresented: $showConfirmEmailSheet, onDismiss: {
            Task {
                _ = await authVM.checkVerificationStatus()
            }
        }) {
            ConfirmEmailView()
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showRulesSheet) {
            PostingRulesView(onAgree: {
                hasAcceptedPostingRules = true
                showRulesSheet = false
            })
            .environmentObject(authVM)
        }
        .sheet(isPresented: $showDraftsSheet) {
            DraftsSheetView(
                drafts: viewModel.availableDrafts,
                onResume: { draft in
                    viewModel.resumeDraft(id: draft.id)
                    showDraftsSheet = false
                },
                onDeleteConfirmed: { draft in
                    viewModel.deleteDraft(id: draft.id)
                }
            )
        }
    }

    private func showRulesIfNeeded() {
        if authVM.isEmailVerified && !hasAcceptedPostingRules {
            showRulesSheet = true
        }
    }
}

struct ProgressIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Constants.Colors.primary : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Navigation Buttons
struct NavigationButtonsView: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let canSaveDraft: Bool
    let isBusy: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void
    let onSaveDraft: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if currentStep > 1 {
                Button(action: onBack) {
                    Text("Back")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Constants.Colors.primary, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: currentStep == totalSteps ? onFinish : onNext) {
                Text(currentStep == totalSteps ? (isBusy ? "Posting…" : "Post") : "Next")
                    .font(FontManager.buttonText())
                    .foregroundColor(canProceed && !isBusy ? Constants.Colors.buttonText : Constants.Colors.primary.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed && !isBusy ? Constants.Colors.primary : Color.gray.opacity(0.35))
                    .cornerRadius(20)
            }
            .disabled(!canProceed || isBusy)
            .buttonStyle(PlainButtonStyle())

            if currentStep == totalSteps {
                Button(action: onSaveDraft) {
                    Text("Save Draft")
                        .font(FontManager.buttonText())
                        .foregroundColor(
                            canSaveDraft && !isBusy
                                ? Constants.Colors.primary
                                : Constants.Colors.primary.opacity(0.4)
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.Colors.accent.opacity(canSaveDraft ? 0.75 : 0.35))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Constants.Colors.primary.opacity(canSaveDraft ? 1 : 0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSaveDraft || isBusy)
                .accessibilityHint("Saves this Spot without publishing it")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct DraftsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let drafts: [PostComposerDraftSummary]
    let onResume: (PostComposerDraftSummary) -> Void
    let onDeleteConfirmed: (PostComposerDraftSummary) -> Void
    @State private var pendingDeleteDraft: PostComposerDraftSummary?

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty {
                    VStack(spacing: 12) {
                        Text("No drafts yet")
                            .font(FontManager.sectionHeader())
                            .foregroundColor(Constants.Colors.primary)
                        Text("Start a new spot and save it here before posting.")
                            .font(FontManager.primaryText())
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Constants.Colors.background)
                } else {
                    List {
                        ForEach(drafts) { draft in
                            Button(action: { onResume(draft) }) {
                                HStack(spacing: 12) {
                                    Group {
                                        if let image = PostDraftStore.loadPreviewImage(fileName: draft.previewImageFileName) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12).fill(Constants.Colors.accent.opacity(0.35))
                                                Image(systemName: "photo")
                                                    .foregroundColor(Constants.Colors.primary)
                                            }
                                        }
                                    }
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(draft.placeName ?? "Untitled draft") • \(draft.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.primary)
                                        Text(draft.status == .autosaved ? "Unfinished" : "Saved draft")
                                            .font(.caption2)
                                            .foregroundColor(Constants.Colors.primary.opacity(0.8))
                                        if !draft.vibeTags.isEmpty {
                                            Text(draft.vibeTags.prefix(2).joined(separator: " • "))
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Constants.Colors.primary.opacity(0.12), lineWidth: 1)
                                )
                                .cornerRadius(14)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDeleteDraft = draft
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Constants.Colors.background)
                }
            }
            .navigationTitle("Drafts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Constants.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CustomBackButton {
                        dismiss()
                    }
                }
            }
            .background(Constants.Colors.background.ignoresSafeArea())
            .overlay {
                if pendingDeleteDraft != nil {
                    CustomConfirmationDialog(
                        title: "Delete draft?",
                        message: "This removes the draft permanently.",
                        confirmTitle: "Delete",
                        cancelTitle: "Cancel",
                        onConfirm: {
                            if let draft = pendingDeleteDraft {
                                onDeleteConfirmed(draft)
                            }
                            pendingDeleteDraft = nil
                        },
                        onCancel: {
                            pendingDeleteDraft = nil
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Location Data Model
struct LocationData: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let placeName: String
    let address: String?
    let isCustomName: Bool

    init(coordinate: CLLocationCoordinate2D, placeName: String, address: String?, isCustomName: Bool = false) {
        self.coordinate = coordinate
        self.placeName = placeName
        self.address = address
        self.isCustomName = isCustomName
    }

    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    let isError: Bool
    var body: some View {
        Text(message)
            .font(FontManager.primaryText())
            .foregroundColor(Constants.Colors.buttonText)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(isError ? Color.red : Constants.Colors.primary)
            .cornerRadius(20)
            .shadow(radius: 4)
    }
}

#Preview {
    PostFlowView(onPostQueued: nil)
        .environmentObject(AuthViewModel())
}
