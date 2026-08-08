import Foundation
import Supabase
import UIKit

final class ProfilePictureUploader {
    static let shared = ProfilePictureUploader()
    private init() {}

    // For signup flow - user doesn't exist yet, so we need to pass UID
    func uploadProfilePictureForSignup(image: UIImage, uid: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            SpotLogger.log(ProfilePictureUploaderLogs.compressionFailed)
            completion(.failure(NSError(domain: "ProfilePictureUploader", code: 400, userInfo: [NSLocalizedDescriptionKey: "Image conversion failed."])) )
            return
        }
        guard let userUUID = InputValidation.parseUUID(uid, context: "ProfilePictureUploader.signup") else {
            completion(.failure(NSError(domain: "ProfilePictureUploader", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])) )
            return
        }
        Task {
            do {
                let path = "\(userUUID.uuidString.lowercased())/profile.jpg"
                SpotLogger.log(ProfilePictureUploaderLogs.uploadingToPath, details: ["path": path])
                let imageUrl = try await SupabaseUserService.shared.uploadProfileAvatarJPEG(imageData, userId: userUUID)
                SpotLogger.log(ProfilePictureUploaderLogs.uploadedSuccessfully, details: ["url": imageUrl])
                completion(.success(imageUrl))
            } catch {
                SpotLogger.log(ProfilePictureUploaderLogs.uploadFailed, details: ["error": error.localizedDescription])
                completion(.failure(error))
            }
        }
    }

    // For existing users updating their profile picture
    func uploadProfilePicture(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = SpotAuthBridge.currentUserId else {
            completion(.failure(NSError(domain: "ProfilePictureUploader", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }

        uploadProfilePictureForSignup(image: image, uid: uid, completion: completion)
    }
}
