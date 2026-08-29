//
//  PostAuthSetupFlowView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import PhotosUI
import Supabase

struct PostAuthSetupFlowView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var termsStore = PreAuthTermsAgreementStore.shared

    let onComplete: () -> Void

    @State private var username: String = ""
    @State private var originalUsername: String = ""
    @State private var selectedProfileImage: UIImage?
    @State private var existingProfileImageURL: String?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isSavingProfile: Bool = false
    @State private var errorMessage: String?
    @State private var alreadyAcceptedActiveTerms: Bool = false
    /// True once `loadCurrentProfile` has read the existing username row
    /// from Supabase. We wait for this before committing to PFP-only mode
    /// so a brief async loading window can't flash the wrong UI.
    @State private var profileLoadCompleted: Bool = false

    private let termsService: TermsAcceptanceServicing

    init(termsService: TermsAcceptanceServicing = TermsAcceptanceService.shared, onComplete: @escaping () -> Void) {
        self.termsService = termsService
        self.onComplete = onComplete
    }

    private var isTermsAgreed: Bool {
        alreadyAcceptedActiveTerms || termsStore.hasAgreed
    }

    private var canContinue: Bool {
        isTermsAgreed && !isSavingProfile
    }
    
    private var isPfpOnlyMode: Bool {
        profileLoadCompleted
            && !originalUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stepTitle: String {
        isPfpOnlyMode ? "Add a profile picture" : "Choose a username"
    }

    private var stepSubtitle: String {
        isPfpOnlyMode
            ? "Pick a photo for your profile so people can recognize you."
            : "Pick a username so other people can find you. You can add a profile photo later — it's optional."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                profileStep

                if let errorMessage {
                    Text(errorMessage)
                        .font(FontManager.primaryText())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Colors.background.ignoresSafeArea())
        .task {
            await loadCurrentProfile()
            await loadTermsAcceptanceState()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedProfileImage = image
                }
            }
        }
    }

    private var profileStep: some View {
        VStack(spacing: 16) {
            Text(stepTitle)
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)
            Text(stepSubtitle)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // PRD §9 / §7.2: profile photo is collected in the Optional
            // Setup flow that runs immediately after this screen. We keep
            // the photo picker visible only in the legacy PFP-only mode
            // (which should no longer be routed here in practice — the
            // Optional Setup flow now owns the photo step). For the
            // username-collection case we render a plain person silhouette
            // so the screen stays focused on the username decision.
            if isPfpOnlyMode {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    ZStack {
                        if let image = selectedProfileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 2))
                        } else if let existingProfileImageURL, let url = URL(string: existingProfileImageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 104)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 2))
                                default:
                                    Circle()
                                        .fill(Constants.Colors.background)
                                        .frame(width: 104, height: 104)
                                        .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 2))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 38))
                                                .foregroundColor(Constants.Colors.primary)
                                        )
                                }
                            }
                        } else {
                            Circle()
                                .fill(Constants.Colors.background)
                                .frame(width: 104, height: 104)
                                .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 2))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(Constants.Colors.primary)
                                )
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Circle()
                    .fill(Constants.Colors.background)
                    .frame(width: 104, height: 104)
                    .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 38))
                            .foregroundColor(Constants.Colors.primary)
                    )
                    .accessibilityHidden(true)

                SettingsTextField(title: "Username", text: $username)
                    .padding(.horizontal, 32)
            }

            // Apple Guideline 1.2: explicit Terms of Use + Privacy Policy
            // agreement is required before account registration completes.
            // We keep the Welcome-screen gate AND show the checkbox here so
            // Sign in with Apple users (whose first registration step is this
            // view) cannot bypass it.
            TermsAgreementCheckboxView(
                isAgreed: Binding(
                    get: { isTermsAgreed },
                    set: { newValue in
                        termsStore.setAgreed(newValue)
                    }
                ),
                termsURL: termsStore.termsURL,
                privacyURL: termsStore.privacyURL,
                onLinkTapped: nil
            )
            .padding(.horizontal, 32)
            .accessibilityIdentifier("postAuth.termsCheckbox")

            Button {
                Task { await saveProfileAndContinue() }
            } label: {
                Text(isSavingProfile ? "Saving..." : "Continue")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Constants.Colors.primary : Constants.Colors.primary.opacity(0.45))
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1.0 : 0.85)
            .padding(.horizontal, 32)
            .accessibilityIdentifier("postAuth.continueButton")
        }
    }

    private func loadCurrentProfile() async {
        guard let uidString = authVM.userId, let uid = UUID(uuidString: uidString) else {
            await MainActor.run { profileLoadCompleted = true }
            return
        }
        struct Row: Decodable {
            let username: String
            let profile_image_url: String?
        }
        let row: Row? = try? await supabase
            .from("users")
            .select("username,profile_image_url")
            .eq("id", value: uid)
            .single()
            .execute()
            .value
        await MainActor.run {
            if let row {
                username = row.username
                originalUsername = row.username
                existingProfileImageURL = row.profile_image_url?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            profileLoadCompleted = true
        }
    }

    /// Loads the active terms version (so links resolve to the live URLs) and
    /// determines whether the calling user has already accepted them. The
    /// checkbox is pre-checked only when acceptance has already been recorded
    /// for this user; otherwise reviewers see an unchecked state inside the
    /// registration step.
    @MainActor
    private func loadTermsAcceptanceState() async {
        await termsStore.loadActiveVersion()
        do {
            let accepted = try await termsService.hasAcceptedActiveTerms()
            alreadyAcceptedActiveTerms = accepted
        } catch {
            alreadyAcceptedActiveTerms = false
        }
    }

    @MainActor
    private func saveProfileAndContinue() async {
        errorMessage = nil
        guard isTermsAgreed else {
            errorMessage = "Please agree to the Terms of Use and Privacy Policy to continue."
            termsStore.logGated(action: "post_auth_setup_continue")
            return
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Username is required."
            return
        }
        // Profile photo is OPTIONAL per PRD §7.3 / §9. The Optional Setup
        // flow that runs after this screen offers a dedicated profile-photo
        // step where the user can take/choose one or skip entirely.
        guard let uidString = authVM.userId, let uid = UUID(uuidString: uidString) else {
            errorMessage = "No authenticated user."
            return
        }

        let validator = UsernameValidator()
        switch validator.validate(trimmed) {
        case .ok: break
        case .tooShort: errorMessage = "Username is too short."; return
        case .tooLong: errorMessage = "Username is too long."; return
        case .invalidChars: errorMessage = "Username has invalid characters."; return
        case .reserved: errorMessage = "That username is reserved."; return
        case .blocked: errorMessage = "That username isn’t allowed."; return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            if trimmed.lowercased() != originalUsername.lowercased() {
                let available = await authVM.isUsernameAvailable(trimmed)
                if !available {
                    errorMessage = "Username is already taken."
                    return
                }
            }

            var avatarURLToPersist = existingProfileImageURL
            if let image = selectedProfileImage {
                guard let data = image.jpegData(compressionQuality: 0.7) else {
                    errorMessage = "Failed to process image."
                    return
                }
                avatarURLToPersist = try await SupabaseUserService.shared.uploadProfileAvatarJPEG(data, userId: uid)
            }

            struct Patch: Encodable {
                let username: String
                let username_lower: String
                let profile_image_url: String?
            }

            try await supabase
                .from("users")
                .update(Patch(
                    username: trimmed,
                    username_lower: trimmed.lowercased(),
                    profile_image_url: avatarURLToPersist
                ))
                .eq("id", value: uid)
                .execute()

            // Best-effort: keep auth metadata in sync for clients that read username there.
            do {
                _ = try await supabase.auth.update(
                    user: UserAttributes(
                        data: ["username": .string(trimmed)]
                    )
                )
            } catch {
                // `users` row is already updated; continuing avoids blocking the user on auth-only failures.
            }

            // Record terms acceptance now that the registration step has
            // completed. Failures fall back to the post-auth update gate
            // surfaced by `RootView.refreshTermsAcceptanceRequirement()`, so
            // the user is never silently un-recorded.
            if !alreadyAcceptedActiveTerms {
                do {
                    try await termsService.recordAcceptance()
                    alreadyAcceptedActiveTerms = true
                    SpotLogger.log(TermsAcceptanceLogs.acceptanceRecorded, details: [
                        "source": "post_auth_setup"
                    ])
                } catch {
                    SpotLogger.log(TermsAcceptanceLogs.acceptanceRecordFailed, details: [
                        "source": "post_auth_setup",
                        "error": error.localizedDescription
                    ])
                }
            }

            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PostAuthSetupFlowView(onComplete: {})
        .environmentObject(AuthViewModel())
        .environmentObject(PermissionManager.shared)
}
