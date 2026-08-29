//
//  BlockedUsersView.swift
//  Spot
//
//  Created by Edward Wynman on 8/14/25.
//

import SwiftUI
import Supabase

struct BlockedUsersView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var blockedUserDetails: [BlockedUserInfo] = []
    @State private var isLoading = true
    @State private var showUnblockConfirm = false
    @State private var userToUnblock: BlockedUserInfo?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                        .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                Text("Blocked Users")
                    .font(FontManager.sectionHeader())
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)

                Spacer()

                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.clear)
                    .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .buttonStyle(PlainButtonStyle())

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading blocked users...")
                Spacer()
            } else if blockedUserDetails.isEmpty {
                emptyStateView
            } else {
                blockedUsersList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F3EF"))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadBlockedUsers()
        }
        .alert("Unblock User", isPresented: $showUnblockConfirm) {
            Button("Unblock", role: .destructive) {
                if let user = userToUnblock {
                    Task { await unblockUser(user) }
                }
            }
            Button("Cancel", role: .cancel) {
                userToUnblock = nil
            }
        } message: {
            if let user = userToUnblock {
                Text("Are you sure you want to unblock @\(user.username)?")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Blocked Users")
                .font(FontManager.sectionHeader())
                .foregroundColor(Constants.Colors.primary)

            Text("You haven't blocked anyone.")
                .font(FontManager.primaryText())
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F3EF"))
    }

    private var blockedUsersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(blockedUserDetails) { user in
                    blockedUserRow(user)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F3EF"))
    }

    private func blockedUserRow(_ user: BlockedUserInfo) -> some View {
        HStack(spacing: 12) {
            // Profile image
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable()
                       .aspectRatio(contentMode: .fill)
                       .frame(width: 50, height: 50)
                       .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }

            // Username
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user.username)")
                    .font(FontManager.primaryText())
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)

                Text("Blocked")
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)
            }

            Spacer()

            // Unblock button
            Button {
                userToUnblock = user
                showUnblockConfirm = true
            } label: {
                Text("Unblock")
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Constants.Colors.background)
        .cornerRadius(12)
    }

    private func loadBlockedUsers() {
        isLoading = true
        Task {
            do {
                guard let currentId = authVM.userId, let uid = UUID(uuidString: currentId) else {
                    await MainActor.run {
                        self.blockedUserDetails = []
                        self.isLoading = false
                    }
                    return
                }

                struct BlockRow: Decodable { let blocked_user_id: UUID }
                let blockRows: [BlockRow] = try await supabase
                    .from("user_blocks")
                    .select("blocked_user_id")
                    .eq("blocker_id", value: uid)
                    .execute()
                    .value

                let ids = blockRows.map(\.blocked_user_id)
                let idStrings = ids.map { $0.uuidString }

                await MainActor.run {
                    self.authVM.blockedUsers = idStrings
                }

                guard !ids.isEmpty else {
                    await MainActor.run {
                        self.blockedUserDetails = []
                        self.isLoading = false
                    }
                    return
                }

                struct UserRow: Decodable {
                    let id: UUID
                    let username: String
                    let profile_image_url: String?
                }
                let rows: [UserRow] = try await supabase
                    .from(SupabaseTableName.usersPublic)
                    .select("id,username,profile_image_url")
                    .in("id", values: ids)
                    .execute()
                    .value
                let userDetails = rows.map { row in
                    BlockedUserInfo(
                        id: row.id.uuidString,
                        username: row.username,
                        profileImageURL: row.profile_image_url
                    )
                }

                await MainActor.run {
                    self.blockedUserDetails = userDetails
                    self.isLoading = false
                }
            } catch {
                SpotLogger.log(BlockedUsersViewLogs.loadBlockedUserDetailsFailed, details: ["error": error.localizedDescription])
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    @MainActor
    private func unblockUser(_ user: BlockedUserInfo) async {
        do {
            try await authVM.unblockUser(userId: user.id)
            blockedUserDetails.removeAll { $0.id == user.id }
            userToUnblock = nil
            SpotLogger.log(BlockedUsersViewLogs.userUnblocked, details: ["userId": user.id])
        } catch {
            SpotLogger.log(BlockedUsersViewLogs.unblockUserFailed, details: ["error": error.localizedDescription])
            userToUnblock = nil
        }
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.blockedUsers = ["u2", "u3"]
    return BlockedUsersView()
        .environmentObject(auth)
}

struct BlockedUserInfo: Identifiable {
    let id: String
    let username: String
    let profileImageURL: String?
}
