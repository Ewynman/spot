import SwiftUI
import PhotosUI
import UIKit
import ImageIO

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var username: String = ""
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPrivate: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var currentPasswordError: String?
    @State private var newPasswordError: String?
    @State private var confirmPasswordError: String?
    @State private var originalUsername: String = ""
    @State private var confirmDelete: Bool = false
    @State private var deletePassword: String = ""
    @State private var profileImageURL: String?
    @State private var selectedProfileImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto: Bool = false
    @State private var showCollectionsNav: Bool = false

    private struct SettingsUserRow: Decodable {
        let username: String
        let email: String?
        let is_private: Bool
        let profile_image_url: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Text("Settings")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .frame(maxWidth: .infinity)

                Spacer().frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Account")
                            NavigationLink {
                                AccountSettingsDetailView(
                                    username: $username,
                                    name: $name,
                                    email: $email,
                                    profileImageURL: $profileImageURL,
                                    selectedProfileImage: $selectedProfileImage,
                                    photoPickerItem: $photoPickerItem,
                                    isUploadingPhoto: $isUploadingPhoto,
                                    currentPassword: $currentPassword,
                                    confirmDelete: $confirmDelete,
                                    deletePassword: $deletePassword,
                                    isSaving: $isSaving,
                                    onSave: saveAccountChanges,
                                    onUploadPhoto: uploadProfilePhoto,
                                    onLogout: { authVM.signOut() },
                                    onDeleteWithPassword: deleteAccountWithPassword,
                                    onDeleteWithAppleToken: deleteAccountWithApple,
                                    onDeleteAppleError: { showToast(message: $0, isError: true) }
                                )
                            } label: {
                                settingsRow(title: "Account settings", icon: "person.crop.circle")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("settings.accountSettingsEntry")
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Security")
                            NavigationLink {
                                SecuritySettingsDetailView(
                                    currentPassword: $currentPassword,
                                    newPassword: $newPassword,
                                    confirmPassword: $confirmPassword,
                                    isPrivate: $isPrivate,
                                    isSaving: $isSaving,
                                    currentPasswordError: $currentPasswordError,
                                    newPasswordError: $newPasswordError,
                                    confirmPasswordError: $confirmPasswordError,
                                    onSave: saveSecurityChanges
                                )
                            } label: {
                                settingsRow(title: "Security options", icon: "lock.shield")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Subscription")
                            NavigationLink {
                                SubscriptionSettingsDetailView(
                                    isPro: authVM.isPro,
                                    proUntil: authVM.proUntil,
                                    onOpenCollections: { showCollectionsNav = true },
                                    onGoPro: { NotificationCenter.default.post(name: .showPaywall, object: nil) },
                                    onManageSubscription: manageSubscriptions,
                                    onRestorePurchases: restorePurchases
                                )
                            } label: {
                                settingsRow(title: "Subscription & Pro", icon: "star")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Permissions")
                            NavigationLink {
                                PermissionsSettingsView()
                            } label: {
                                settingsRow(
                                    title: "Permissions",
                                    icon: "hand.raised",
                                    subtitle: "Location, notifications, camera, photos",
                                    showsTrailingWarning: permissionManager.anyPermissionNeedsAttention
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("settings.permissionsRow")
                            .accessibilityLabel(
                                permissionManager.anyPermissionNeedsAttention
                                ? "Permissions. Some optional permissions are off."
                                : "Permissions"
                            )
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Support")
                            NavigationLink {
                                SupportSettingsDetailView()
                            } label: {
                                settingsRow(
                                    title: "Contact Support",
                                    icon: "envelope.fill",
                                    subtitle: Constants.Legal.supportEmail
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("settings.contactSupportRow")
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Legal")
                            NavigationLink {
                                LegalSettingsDetailView()
                            } label: {
                                settingsRow(title: "Legal documents", icon: "doc.text")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    #if DEBUG
                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Debug")
                            NavigationLink {
                                LoggingSettingsDetailView()
                            } label: {
                                settingsRow(
                                    title: "Console logging",
                                    icon: "ladybug",
                                    subtitle: "Feed, upload, auth…"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            NavigationLink {
                                AlgorithmDebugView()
                            } label: {
                                settingsRow(
                                    title: "Algorithm snapshot",
                                    icon: "sparkles",
                                    subtitle: "Raw user_feed_profiles row"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    #endif
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .accessibilityIdentifier("settings.screenRoot")
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showCollectionsNav) {
            CollectionsView()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let error = errorMessage {
                    ToastView(message: error, isError: true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let success = successMessage {
                    ToastView(message: success, isError: false)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 8)
        }
        .task(id: authVM.userId) {
            await load()
        }
        .onAppear {
            permissionManager.updatePermissionStatuses()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            permissionManager.updatePermissionStatuses()
        }
    }

    private func load() async {
        guard let userId = authVM.userId, let uid = UUID(uuidString: userId) else { return }
        do {
            let row: SettingsUserRow = try await supabase
                .from("users")
                .select("username,email,is_private,profile_image_url")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            let authUser = try? await supabase.auth.user()
            await MainActor.run {
                username = row.username
                originalUsername = username
                name = (authUser?.userMetadata["full_name"]?.stringValue) ?? ""
                email = row.email ?? (authUser?.email ?? SpotAuthBridge.currentUserEmail ?? "")
                isPrivate = row.is_private
                profileImageURL = row.profile_image_url
            }
        } catch {
            SpotLogger.log(SettingsViewLogs.loadProfileFailed, details: ["userId": userId, "error": error.localizedDescription])
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func save() {
        errorMessage = nil
        successMessage = nil
        currentPasswordError = nil
        newPasswordError = nil
        confirmPasswordError = nil
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username cannot be empty"
            return
        }
        if !newPassword.isEmpty || !confirmPassword.isEmpty {
            guard newPassword == confirmPassword else {
                confirmPasswordError = "Passwords do not match."
                return
            }
            switch PasswordValidator.validate(newPassword) {
            case .ok:
                break
            case .failure(let message):
                newPasswordError = message
                return
            }
        }
        let isEmailChange = !email.isEmpty && email != SpotAuthBridge.currentUserEmail
        let isPasswordChange = !newPassword.isEmpty
        if (isEmailChange || isPasswordChange) &&
            currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentPasswordError = "Current password is required for email or password changes."
            return
        }

        isSaving = true

        // Validation
        Task {
            if username != originalUsername {
                let available = await authVM.isUsernameAvailable(username)
                if !available {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Username is already taken"
                    }
                    return
                }
            }
        }

        // Update Supabase profile fields
        let group = DispatchGroup()
        var firstError: Error?

        // Username validation before updating
        let validator = UsernameValidator()
        switch validator.validate(username) {
        case .ok: break
        case .tooShort: isSaving = false; errorMessage = "Username is too short"; return
        case .tooLong: isSaving = false; errorMessage = "Username is too long"; return
        case .invalidChars: isSaving = false; errorMessage = "Username has invalid characters"; return
        case .reserved: isSaving = false; errorMessage = "That username is reserved"; return
        case .blocked:
            SpotLogger.log(SettingsViewLogs.usernameBlocked, details: ["raw": username, "norm": validator.normalized(username)])
            isSaving = false; errorMessage = "That username isn’t allowed"; return
        }

        group.enter()
        authVM.updateUsername(username) { result in
            if case let .failure(err) = result { firstError = firstError ?? err }
            group.leave()
        }

        group.enter()
        authVM.updateName(name) { result in
            if case let .failure(err) = result { firstError = firstError ?? err }
            group.leave()
        }

        if isEmailChange {
            // Ask user to confirm change and send verification link
            DispatchQueue.main.async {
                let newEmail = email
                // Present inline confirm style in place
                let alert = UIAlertController(title: "Confirm new email", message: "We’ll send a verification link to \(newEmail). Your email will update after you verify.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
                alert.addAction(UIAlertAction(title: "Send & Verify", style: .default, handler: { _ in
                    Task {
                        do {
                            // Enforce current-password reauth before any email change.
                            let reauthResult: Result<Void, Error> = await withCheckedContinuation { cont in
                                authVM.reauthenticate(currentPassword: currentPassword) { result in
                                    cont.resume(returning: result)
                                }
                            }
                            if case let .failure(reauthError) = reauthResult {
                                throw reauthError
                            }
                            try await authVM.verifyBeforeUpdateEmail(newEmail)
                            // Navigate to confirmation screen
                            // Use SwiftUI navigation push via a navigation state instead of presenting UIKit controller
                            // Fallback: show a lightweight toast to prompt user to check inbox
                            successMessage = "Verification email sent. Check your inbox."
                        } catch {
                            SpotLogger.log(SettingsViewLogs.verifyBeforeUpdateEmailFailed, details: ["newEmail": newEmail, "error": error.localizedDescription])
                            firstError = firstError ?? error
                        }
                    }
                }))
                UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController?.present(alert, animated: true)
            }
        }

        if isPasswordChange {
            group.enter()
            authVM.reauthenticate(currentPassword: currentPassword) { reauth in
                switch reauth {
                case .failure(let error):
                    firstError = firstError ?? error
                    group.leave()
                case .success:
                    authVM.updatePassword(newPassword) { result in
                        if case let .failure(err) = result { firstError = firstError ?? err }
                        group.leave()
                    }
                }
            }
        }

        group.enter()
        authVM.setPrivateAccount(isPrivate) { result in
            if case let .failure(err) = result { firstError = firstError ?? err }
            group.leave()
        }

        group.notify(queue: .main) {
            isSaving = false
            if let err = firstError {
                SpotLogger.log(SettingsViewLogs.saveFailed, details: ["error": err.localizedDescription])
                showToast(message: err.localizedDescription, isError: true)
            } else {
                SpotLogger.log(SettingsViewLogs.saveSuccess, details: [
                    "usernameChanged": username != originalUsername,
                    "emailChanged": email != SpotAuthBridge.currentUserEmail ?? "",
                    "isPrivate": isPrivate
                ])
                showToast(message: "Settings updated", isError: false)
            }
        }
    }

    private func saveAccountChanges() {
        errorMessage = nil
        successMessage = nil
        currentPasswordError = nil

        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username cannot be empty"
            return
        }

        isSaving = true
        let isEmailChange = !email.isEmpty && email != SpotAuthBridge.currentUserEmail
        if isEmailChange && currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isSaving = false
            currentPasswordError = "Current password is required for email changes."
            return
        }

        Task {
            if username != originalUsername {
                let available = await authVM.isUsernameAvailable(username)
                if !available {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Username is already taken"
                    }
                    return
                }
            }

            let validator = UsernameValidator()
            switch validator.validate(username) {
            case .ok: break
            case .tooShort:
                await MainActor.run { isSaving = false; errorMessage = "Username is too short" }
                return
            case .tooLong:
                await MainActor.run { isSaving = false; errorMessage = "Username is too long" }
                return
            case .invalidChars:
                await MainActor.run { isSaving = false; errorMessage = "Username has invalid characters" }
                return
            case .reserved:
                await MainActor.run { isSaving = false; errorMessage = "That username is reserved" }
                return
            case .blocked:
                await MainActor.run { isSaving = false; errorMessage = "That username isn’t allowed" }
                return
            }

            let group = DispatchGroup()
            var firstError: Error?

            group.enter()
            authVM.updateUsername(username) { result in
                if case let .failure(err) = result { firstError = firstError ?? err }
                group.leave()
            }

            group.enter()
            authVM.updateName(name) { result in
                if case let .failure(err) = result { firstError = firstError ?? err }
                group.leave()
            }

            if isEmailChange {
                group.enter()
                authVM.reauthenticate(currentPassword: currentPassword) { reauth in
                    switch reauth {
                    case .failure(let error):
                        firstError = firstError ?? error
                        group.leave()
                    case .success:
                        Task {
                            do {
                                try await authVM.verifyBeforeUpdateEmail(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                            } catch {
                                firstError = firstError ?? error
                            }
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                isSaving = false
                if let err = firstError {
                    showToast(message: err.localizedDescription, isError: true)
                } else {
                    showToast(message: isEmailChange ? "Verification code sent to new email" : "Account settings updated", isError: false)
                }
            }
        }
    }

    private func saveSecurityChanges() {
        errorMessage = nil
        successMessage = nil
        currentPasswordError = nil
        newPasswordError = nil
        confirmPasswordError = nil

        let isPasswordChange = !newPassword.isEmpty || !confirmPassword.isEmpty
        if isPasswordChange {
            guard newPassword == confirmPassword else {
                confirmPasswordError = "Passwords do not match."
                return
            }
            switch PasswordValidator.validate(newPassword) {
            case .ok: break
            case .failure(let message):
                newPasswordError = message
                return
            }
            if currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentPasswordError = "Current password is required for password changes."
                return
            }
        }

        isSaving = true
        let group = DispatchGroup()
        var firstError: Error?

        group.enter()
        authVM.setPrivateAccount(isPrivate) { result in
            if case let .failure(err) = result { firstError = firstError ?? err }
            group.leave()
        }

        if isPasswordChange {
            group.enter()
            authVM.reauthenticate(currentPassword: currentPassword) { reauth in
                switch reauth {
                case .failure(let error):
                    firstError = firstError ?? error
                    group.leave()
                case .success:
                    authVM.updatePassword(newPassword) { result in
                        if case let .failure(err) = result { firstError = firstError ?? err }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            isSaving = false
            if let err = firstError {
                showToast(message: err.localizedDescription, isError: true)
            } else {
                showToast(message: "Security settings updated", isError: false)
            }
        }
    }

    private func deleteAccountWithPassword() {
        guard !isSaving else { return }
        SpotLogger.log(SettingsViewLogs.deleteAccountTapped, details: [
            "confirmDelete": confirmDelete,
            "reauth": "password",
            "hasPassword": !deletePassword.isEmpty
        ])
        guard confirmDelete, !deletePassword.isEmpty else {
            SpotLogger.log(SettingsViewLogs.deleteAccountBlockedMissingConfirmation)
            showToast(
                message: "Turn on the confirmation switch and enter your password to delete your account.",
                isError: true
            )
            return
        }
        isSaving = true
        authVM.deleteAccount(password: deletePassword) { result in
            handleDeleteAccountResult(result)
        }
    }

    private func deleteAccountWithApple(_ appleIDToken: String, nonce: String) {
        guard !isSaving else { return }
        SpotLogger.log(SettingsViewLogs.deleteAccountTapped, details: [
            "confirmDelete": confirmDelete,
            "reauth": "apple"
        ])
        guard confirmDelete else {
            SpotLogger.log(SettingsViewLogs.deleteAccountBlockedMissingConfirmation)
            showToast(message: "Turn on the confirmation switch before deleting your account.", isError: true)
            return
        }
        isSaving = true
        authVM.deleteAccount(appleIDToken: appleIDToken, nonce: nonce) { result in
            handleDeleteAccountResult(result)
        }
    }

    private func handleDeleteAccountResult(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            isSaving = false
            switch result {
            case .success:
                showToast(message: "Account deleted", isError: false)
                dismiss()
            case .failure(let error):
                showToast(message: error.localizedDescription, isError: true)
            }
        }
    }

    private func manageSubscriptions() {
        Task {
            do {
                try await SubscriptionManager.shared.manageSubscriptions()
            } catch {
                await MainActor.run { showToast(message: error.localizedDescription, isError: true) }
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                guard let userId = authVM.userId, let appAccountToken = UUID(uuidString: userId) else {
                    await MainActor.run { showToast(message: "Please sign in again before restoring Pro.", isError: true) }
                    return
                }
                try await SubscriptionManager.shared.restorePurchases()
                switch await SubscriptionManager.shared.refreshEntitlement(for: appAccountToken) {
                case .active(let expirationDate):
                    await authVM.setProActive(true, proUntil: expirationDate)
                    await MainActor.run { showToast(message: "Subscription restored", isError: false) }
                case .linkedToDifferentAccount:
                    await authVM.setProActive(false)
                    await MainActor.run {
                        showToast(
                            message: SubscriptionPurchaseError.subscriptionLinkedToDifferentAccount.localizedDescription,
                            isError: true
                        )
                    }
                case .inactive:
                    await MainActor.run { showToast(message: "No active subscription found", isError: true) }
                }
            } catch {
                await MainActor.run { showToast(message: error.localizedDescription, isError: true) }
            }
        }
    }

    private func showToast(message: String, isError: Bool) {
        if isError {
            errorMessage = message
            successMessage = nil
        } else {
            successMessage = message
            errorMessage = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                errorMessage = nil
                successMessage = nil
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func uploadProfilePhoto(_ image: UIImage) {
        SpotLogger.log(SettingsViewLogs.profilePhotoUploadStart)
        isUploadingPhoto = true
        errorMessage = nil
        successMessage = nil
        guard let uid = SpotAuthBridge.currentUserId, let uuid = UUID(uuidString: uid) else {
            isUploadingPhoto = false
            showToast(message: "No user session", isError: true)
            SpotLogger.log(SettingsViewLogs.profilePhotoUploadNoUser)
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            isUploadingPhoto = false
            showToast(message: "Failed to process image", isError: true)
            SpotLogger.log(SettingsViewLogs.profilePhotoUploadFailed, details: ["error": "JPEG conversion failed"])
            return
        }
        Task {
            do {
                struct AvatarPatch: Encodable { let profile_image_url: String }
                let url = try await SupabaseUserService.shared.uploadProfileAvatarJPEG(data, userId: uuid)
                try await supabase
                    .from("users")
                    .update(AvatarPatch(profile_image_url: url))
                    .eq("id", value: uuid)
                    .execute()
                await MainActor.run {
                    isUploadingPhoto = false
                    profileImageURL = url
                    selectedProfileImage = nil
                    showToast(message: "Profile photo updated", isError: false)
                    SpotLogger.log(SettingsViewLogs.profilePhotoUpdated)
                }
            } catch {
                await MainActor.run {
                    isUploadingPhoto = false
                    showToast(message: "Failed to update profile picture: \(error.localizedDescription)", isError: true)
                    SpotLogger.log(SettingsViewLogs.profilePhotoUpdateSupabaseFailed, details: ["error": error.localizedDescription])
                }
            }
        }
    }
}

private struct AccountSettingsDetailView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var username: String
    @Binding var name: String
    @Binding var email: String
    @Binding var profileImageURL: String?
    @Binding var selectedProfileImage: UIImage?
    @Binding var photoPickerItem: PhotosPickerItem?
    @Binding var isUploadingPhoto: Bool
    @Binding var currentPassword: String
    @Binding var confirmDelete: Bool
    @Binding var deletePassword: String
    @Binding var isSaving: Bool
    let onSave: () -> Void
    let onUploadPhoto: (UIImage) -> Void
    let onLogout: () -> Void
    let onDeleteWithPassword: () -> Void
    let onDeleteWithAppleToken: (_ idToken: String, _ nonce: String) -> Void
    let onDeleteAppleError: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Account", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(spacing: 16) {
                            sectionHeader("Profile")
                            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                HStack(spacing: 12) {
                                    profileImage
                                    Text(isUploadingPhoto ? "Uploading..." : "Change profile photo")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(Constants.Colors.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Constants.Colors.primary, lineWidth: 1)
                                )
                            }
                            .onChange(of: photoPickerItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = downsampledImage(from: data, maxPixelSize: 1024) {
                                        selectedProfileImage = uiImage
                                        onUploadPhoto(uiImage)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            SettingsTextField(title: "Username", text: $username)
                            SettingsTextField(title: "Display Name", text: $name)
                            SettingsTextField(title: "Email", text: $email, keyboardType: .emailAddress)
                            SettingsSecureField(title: "Current Password (for email change)", text: $currentPassword)

                            Button(action: onSave) {
                                Text(isSaving ? "Saving..." : "Save Account Changes")
                                    .font(FontManager.buttonText())
                                    .foregroundColor(Constants.Colors.buttonText)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Constants.Colors.primary)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isSaving)
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Account Actions")
                            Button(action: onLogout) {
                                settingsRow(title: "Log Out", icon: "arrow.right.square.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Delete Account")
                            Toggle(isOn: $confirmDelete) {
                                Text("I understand this permanently deletes my account")
                                    .font(FontManager.primaryText())
                                    .foregroundColor(Constants.Colors.primary)
                            }
                            .tint(Constants.Colors.primary)
                            .accessibilityIdentifier("settings.deleteAccountConfirmToggle")

                            if authVM.accountDeletionReauthMethod == .signInWithApple {
                                Text("Confirm with Sign in with Apple, then we’ll permanently delete your account and data.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ThemedAppleSignInButton(
                                    mode: .accountDeletionReauth,
                                    onError: onDeleteAppleError,
                                    onAppleIDToken: onDeleteWithAppleToken
                                )
                                .disabled(!confirmDelete || isSaving)
                            } else {
                                SettingsSecureField(
                                    title: "Password to confirm",
                                    text: $deletePassword,
                                    accessibilityIdentifier: "settings.deleteAccountPasswordField"
                                )
                                Text("Uses your account password (same as sign-in).")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button(action: onDeleteWithPassword) {
                                    settingsRow(title: "Delete Account", icon: "trash.fill", isDestructive: true, showsTrailingChevron: false)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isSaving)
                                .accessibilityIdentifier("settings.deleteAccountButton")
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("settings.accountSettingsScreen")
        .task { await authVM.refreshAccountDeletionReauthMethod() }
    }

    private var profileImage: some View {
        Group {
            if let image = selectedProfileImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let urlString = profileImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().padding(10)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Constants.Colors.primary, lineWidth: 1))
    }
}

private struct SupportSettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Support", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Contact")
                            Text("Questions about your account, safety reports, subscriptions, or App Review? Email us and we’ll respond as soon as we can.")
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                openSupportEmail()
                            } label: {
                                settingsRow(title: Constants.Legal.supportEmail, icon: "envelope.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("settings.supportEmailButton")
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func openSupportEmail() {
        let subject = "Spot Support"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:\(Constants.Legal.supportEmail)?subject=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}

private func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
    let options: CFDictionary = [
        kCGImageSourceShouldCache: false
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
    let downsampleOptions: CFDictionary = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
    return UIImage(cgImage: cgImage)
}

private struct SecuritySettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var currentPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    @Binding var isPrivate: Bool
    @Binding var isSaving: Bool
    @Binding var currentPasswordError: String?
    @Binding var newPasswordError: String?
    @Binding var confirmPasswordError: String?
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Security", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(spacing: 16) {
                            sectionHeader("Password")
                            SettingsSecureField(title: "Current Password", text: $currentPassword)
                            if let currentPasswordError { inlineError(currentPasswordError) }
                            SettingsSecureField(title: "New Password", text: $newPassword)
                            if let newPasswordError { inlineError(newPasswordError) }
                            SettingsSecureField(title: "Confirm Password", text: $confirmPassword)
                            if let confirmPasswordError { inlineError(confirmPasswordError) }
                        }
                    }

                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Privacy")
                            Toggle(isOn: $isPrivate) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Private Account")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(Constants.Colors.primary)
                                    Text("Only approved followers can see your spots")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            .tint(Constants.Colors.primary)

                            NavigationLink {
                                BlockedUsersView()
                            } label: {
                                settingsRow(title: "Blocked Users", icon: "person.slash.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    settingsSection {
                        Button(action: onSave) {
                            Text(isSaving ? "Saving..." : "Save Security Changes")
                                .font(FontManager.buttonText())
                                .foregroundColor(Constants.Colors.buttonText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Constants.Colors.primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isSaving)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SubscriptionSettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let isPro: Bool
    let proUntil: Date?
    let onOpenCollections: () -> Void
    let onGoPro: () -> Void
    let onManageSubscription: () -> Void
    let onRestorePurchases: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Subscription", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Subscription")
                            if isPro {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Constants.Colors.primary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pro Member")
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.primary)
                                        if let proUntil {
                                            Text("Active until \(formatDate(proUntil))")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)

                                Button(action: onOpenCollections) {
                                    settingsRow(title: "Bookmark Collections", icon: "bookmark.fill", subtitle: "Pro")
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: onManageSubscription) {
                                    settingsRow(title: "Manage Subscription", icon: "creditcard.fill")
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Button(action: onGoPro) {
                                    settingsRow(title: "Go Pro", icon: "star.fill")
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: onRestorePurchases) {
                                    settingsRow(title: "Restore Purchases", icon: "arrow.clockwise")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct LegalSettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar(title: "Legal", dismiss: dismiss)
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection {
                        VStack(spacing: 12) {
                            sectionHeader("Legal")
                            Button {
                                UIApplication.shared.open(Constants.Legal.termsURL)
                            } label: {
                                settingsRow(title: "Terms & Conditions", icon: "doc.text.fill")
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                UIApplication.shared.open(Constants.Legal.privacyURL)
                            } label: {
                                settingsRow(title: "Privacy Policy", icon: "lock.shield.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "F5F3EF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

private func settingsTopBar(title: String, dismiss: DismissAction) -> some View {
    HStack {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Constants.Colors.primary)
        }
        .buttonStyle(PlainButtonStyle())

        Text(title)
            .font(FontManager.sectionHeader())
            .foregroundColor(Constants.Colors.primary)
            .frame(maxWidth: .infinity)

        Spacer().frame(width: 40)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
}

private func sectionHeader(_ title: String) -> some View {
    HStack {
        Text(title)
            .font(FontManager.sectionHeader())
            .fontWeight(.semibold)
            .foregroundColor(Constants.Colors.primary)
        Spacer()
    }
}

private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        content()
    }
    .padding(16)
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
}

private func settingsRow(
    title: String,
    icon: String,
    subtitle: String? = nil,
    isDestructive: Bool = false,
    showsTrailingChevron: Bool = true,
    showsTrailingWarning: Bool = false
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundColor(isDestructive ? .red : Constants.Colors.primary)
            .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FontManager.primaryText())
                .foregroundColor(isDestructive ? .red : Constants.Colors.primary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }

        Spacer()

        if showsTrailingWarning {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)
                .accessibilityLabel("Some optional permissions are off")
                .accessibilityIdentifier("settings.permissionsWarningIndicator")
        }

        if showsTrailingChevron {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(isDestructive ? Color.red.opacity(0.1) : Color.clear)
    .cornerRadius(8)
}

struct SettingsTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
                .tint(Constants.Colors.primary)
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .padding()
                .foregroundColor(Constants.Colors.primary)
                .tint(Constants.Colors.primary)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
        }
    }
}

struct SettingsSecureField: View {
    let title: String
    @Binding var text: String
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
            SecureField(title, text: $text)
                .padding()
                .foregroundColor(Constants.Colors.primary)
                .tint(Constants.Colors.primary)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Constants.Colors.primary, lineWidth: 1)
                )
                .accessibilityIdentifier(accessibilityIdentifier ?? title)
        }
    }
}

#Preview {
    SettingsView()
}

// Note: Reuse the global ToastView defined in PostFlow; no local duplicate here.
