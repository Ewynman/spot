//
//  ProfileViewModel.swift
//  Spot
//
//  Created By: Wynman, Edward
//  Date: 03/02/2025
//

import Foundation

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var username: String?
    @Published var profileImageURL: String?
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isPrivateProfile = false
    @Published var isProProfile = false
    @Published var isFollowingUser = false
    @Published var hasRequestedFollow = false
    @Published var canViewContent = true
    @Published var deletingSpotIds: Set<String> = []
    @Published var followRequestsCount: Int = 0

    /// Held `nonisolated(unsafe)` so `deinit` can cancel without crossing `@MainActor`; only touch from this type’s logic / `deinit`.
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?
    private nonisolated(unsafe) var followReqPollTask: Task<Void, Never>?
    private var lastLoadedUserId: String?
    private var hasLoaded = false

    deinit {
        loadTask?.cancel()
        followReqPollTask?.cancel()
    }

    /// Load profile for the given user (nil = current user). Uses ProfileService.
    func loadUser(userId: String?, forceReload: Bool = false) async {
        if forceReload {
            loadTask?.cancel()
        } else {
            guard !isLoading else { return }
            if hasLoaded, lastLoadedUserId == userId { return }
        }

        isLoading = true
        error = nil

        loadTask?.cancel()
        loadTask = Task {
            do {
                let data = try await ProfileService.fetchProfile(for: userId)
                self.username = data.username
                self.profileImageURL = data.profileImageURL
                self.spots = data.spots
                self.isPrivateProfile = data.isPrivate
                self.isProProfile = data.isPro
                self.isFollowingUser = data.isFollowing
                self.hasRequestedFollow = data.hasRequested
                self.canViewContent = data.canView
                self.lastLoadedUserId = userId
                self.hasLoaded = true
                self.isLoading = false
                SpotLogger.log(ProfileViewModelLogs.profileLoaded, details: ["username": data.username])
            } catch {
                self.error = error
                self.isLoading = false
                SpotLogger.log(ProfileViewModelLogs.loadUserFailed, details: ["error": error.localizedDescription])
            }
        }
        await loadTask?.value
    }

    /// Delete spot with optimistic update; rollback on failure.
    @MainActor
    func deleteSpot(_ spot: Spot) async {
        guard let id = spot.id else { return }
        if deletingSpotIds.contains(id) { return }
        deletingSpotIds.insert(id)
        let prevSpots = spots
        spots.removeAll { $0.id == id }

        do {
            guard let uuid = UUID(uuidString: id) else {
                throw NSError(domain: "ProfileViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid spot id"])
            }
            try await SpotSupabaseRepository.deleteSpot(id: uuid)
            deletingSpotIds.remove(id)
        } catch {
            SpotLogger.log(ProfileViewModelLogs.profileDeleteFailed, details: ["error": error.localizedDescription])
            spots = prevSpots
            deletingSpotIds.remove(id)
        }
    }

    func locallyReplaceSpot(_ spot: Spot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else { return }
        spots[index] = spot
    }

    /// Start listening to follow-request count for own private profile.
    func startFollowRequestsListener(ownUserId: String?) {
        stopFollowRequestsListener()
        guard let uid = ownUserId else { return }
        followReqPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let n = try await FollowRequestsService.shared.countPending(targetUserId: uid)
                    self.followRequestsCount = n
                } catch {
                    self.followRequestsCount = 0
                }
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    func stopFollowRequestsListener() {
        followReqPollTask?.cancel()
        followReqPollTask = nil
    }

    func follow(targetUserId: String) {
        isFollowingUser = true
        UserSpotService.shared.follow(userId: targetUserId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure:
                    self.isFollowingUser = false
                case .success:
                    SpotLogger.log(ProfileViewModelLogs.followStateRefreshAfterMutation, details: ["action": "follow"])
                    await self.loadUser(userId: targetUserId, forceReload: true)
                }
            }
        }
    }

    func unfollow(targetUserId: String) {
        isFollowingUser = false
        UserSpotService.shared.unfollow(userId: targetUserId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure:
                    self.isFollowingUser = true
                case .success:
                    SpotLogger.log(ProfileViewModelLogs.followStateRefreshAfterMutation, details: ["action": "unfollow"])
                    await self.loadUser(userId: targetUserId, forceReload: true)
                }
            }
        }
    }

    func requestFollow(targetUserId: String) {
        hasRequestedFollow = true
        UserSpotService.shared.requestFollow(userId: targetUserId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure:
                    self.hasRequestedFollow = false
                case .success:
                    SpotLogger.log(ProfileViewModelLogs.followStateRefreshAfterMutation, details: ["action": "requestFollow"])
                    await self.loadUser(userId: targetUserId, forceReload: true)
                }
            }
        }
    }

    func cancelFollowRequest(targetUserId: String) {
        hasRequestedFollow = false
        UserSpotService.shared.cancelFollowRequest(userId: targetUserId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure:
                    self.hasRequestedFollow = true
                case .success:
                    SpotLogger.log(ProfileViewModelLogs.followStateRefreshAfterMutation, details: ["action": "cancelFollowRequest"])
                    await self.loadUser(userId: targetUserId, forceReload: true)
                }
            }
        }
    }

    // MARK: - Legacy (for existing callers that use current-user-only profile)
    var user: User? {
        guard let id = lastLoadedUserId else { return nil }
        return User(
            id: id,
            username: username ?? "User",
            profileImageURL: profileImageURL,
            isPrivate: isPrivateProfile,
            isCurrentUser: true,
            vibeStats: nil,
            createdAt: nil,
            blockedUsers: nil,
            customVibeTags: nil
        )
    }

    func loadUserProfile() async {
        await loadUser(userId: nil)
    }

    // MARK: - Preview Data
    static let previewViewModel: ProfileViewModel = {
        let vm = ProfileViewModel()
        vm.username = "Eddie Wynman"
        vm.spots = [
            Spot(
                id: "spot1",
                userId: "preview123",
                username: "Eddie Wynman",
                userProfileImageURL: nil,
                imageURL: "https://example.com/spot1.jpg",
                vibeTag: "Sunset Spot",
                latitude: 25.7617,
                longitude: -80.1918,
                locationName: "Miami Beach",
                likes: 10,
                isLiked: false,
                isSaved: true,
                createdAt: Date()
            ),
            Spot(
                id: "spot2",
                userId: "preview123",
                username: "Eddie Wynman",
                userProfileImageURL: nil,
                imageURL: "https://example.com/spot2.jpg",
                vibeTag: "Beach Spot",
                latitude: 25.7616,
                longitude: -80.1917,
                locationName: "South Beach",
                likes: 15,
                isLiked: true,
                isSaved: false,
                createdAt: Date()
            )
        ]
        return vm
    }()

    static let previewOtherUserViewModel: ProfileViewModel = {
        let vm = ProfileViewModel()
        vm.username = "John Doe"
        vm.profileImageURL = "https://example.com/profile.jpg"
        vm.isPrivateProfile = false
        vm.spots = [
            Spot(
                id: "spot3",
                userId: "other123",
                username: "John Doe",
                userProfileImageURL: "https://example.com/profile.jpg",
                imageURL: "https://example.com/spot3.jpg",
                vibeTag: "Night Spot",
                latitude: 25.7615,
                longitude: -80.1916,
                locationName: "Downtown Miami",
                likes: 20,
                isLiked: true,
                isSaved: true,
                createdAt: Date()
            )
        ]
        return vm
    }()

    static let previewPrivateViewModel: ProfileViewModel = {
        let vm = ProfileViewModel()
        vm.username = "Private User"
        vm.isPrivateProfile = true
        return vm
    }()

    static let previewEmptyViewModel: ProfileViewModel = {
        let vm = ProfileViewModel()
        vm.username = "New User"
        vm.spots = []
        return vm
    }()
}

// MARK: - Error Types
extension ProfileViewModel {
    enum ProfileError: LocalizedError {
        case userNotFound
        case spotsFetchFailed
        case unauthorized
        case unknown
        case missingIndex

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "User not found"
            case .spotsFetchFailed:
                return "Failed to load spots"
            case .unauthorized:
                return "You don't have access to view this profile"
            case .unknown:
                return "An unknown error occurred"
            case .missingIndex:
                return "Database index is being created. Please try again in a few minutes."
            }
        }
    }
}
