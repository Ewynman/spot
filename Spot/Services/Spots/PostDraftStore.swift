import Foundation
import UIKit
import CoreLocation

enum PostComposerDraftStatus: String, Codable {
    case autosaved
    case saved
}

enum PostComposerDraftStep: String, Codable {
    case photos
    case location
    case vibes
}

struct PostComposerDraftSummary: Codable, Identifiable, Equatable {
    let id: String
    let status: PostComposerDraftStatus
    let previewImageFileName: String?
    let placeName: String?
    let vibeTags: [String]
    let updatedAt: Date
    let step: PostComposerDraftStep
}

struct PostComposerDraft: Codable, Identifiable {
    let schemaVersion: Int?
    let id: String
    let step: Int
    let status: PostComposerDraftStatus
    let vibeTags: [String]
    let latitude: Double?
    let longitude: Double?
    let placeName: String?
    let address: String?
    let isCustomName: Bool
    let imageFileNames: [String]
    let photoRecords: [PostComposerDraftPhoto]?
    let updatedAt: Date
}

struct PostComposerDraftPhoto: Codable, Equatable {
    let id: UUID
    let originalFileName: String
    let previewFileName: String
    let source: PostComposerPhotoSource
    let edits: PostComposerPhotoEdits
    let processingState: PostComposerPhotoProcessingState
    let processingError: String?
    let createdAt: Date
}

struct PostComposerDraftLoadResult {
    let draft: PostComposerDraft
    let photos: [PostComposerPhoto]
    let location: LocationData?

    var images: [UIImage] { photos.map(\.image) }
}

enum PostDraftStore {
    private static let currentSchemaVersion = 2
    private static let draftIndexFileName = "post-composer-drafts-index.json"
    private static let autosavedDraftID = "autosave"

    private static var draftsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PostDrafts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                SpotLogger.log(PostDraftStoreLogs.draftsDirectoryCreateFailed, details: ["error": error.localizedDescription])
            }
        }
        return dir
    }

    private static var draftIndexURL: URL {
        draftsDirectory.appendingPathComponent(draftIndexFileName)
    }

    private static func draftFileURL(for draftID: String) -> URL {
        draftsDirectory.appendingPathComponent("post-composer-draft-\(draftID).json")
    }

    private static func originalImageFileName(draftID: String, photoID: UUID, revision: String) -> String {
        "draft_\(draftID)_photo_\(photoID.uuidString)_\(revision)_original.jpg"
    }

    private static func previewImageFileName(draftID: String, photoID: UUID, revision: String) -> String {
        "draft_\(draftID)_photo_\(photoID.uuidString)_\(revision)_preview.jpg"
    }

    private static func loadIndex() -> [PostComposerDraftSummary] {
        guard let raw = try? Data(contentsOf: draftIndexURL) else {
            return []
        }
        guard let decoded = try? JSONDecoder().decode([PostComposerDraftSummary].self, from: raw) else {
            SpotLogger.log(PostDraftStoreLogs.draftIndexDecodeFailed)
            return []
        }
        return decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private static func saveIndex(_ summaries: [PostComposerDraftSummary]) {
        guard let encoded = try? JSONEncoder().encode(summaries) else {
            SpotLogger.log(PostDraftStoreLogs.draftIndexEncodeFailed, details: ["stage": "encode"])
            return
        }
        do {
            try encoded.write(to: draftIndexURL, options: .atomic)
        } catch {
            SpotLogger.log(PostDraftStoreLogs.draftIndexEncodeFailed, details: ["stage": "write", "error": error.localizedDescription])
        }
    }

    static func listDrafts() -> [PostComposerDraftSummary] {
        loadIndex()
    }

    static func save(
        step: Int,
        photos: [PostComposerPhoto],
        selectedLocation: LocationData?,
        selectedVibes: [String],
        draftID: String? = nil,
        status: PostComposerDraftStatus = .autosaved
    ) -> String? {
        let resolvedID = draftID ?? (status == .autosaved ? autosavedDraftID : UUID().uuidString)
        let previousDraft = (try? Data(contentsOf: draftFileURL(for: resolvedID)))
            .flatMap { try? JSONDecoder().decode(PostComposerDraft.self, from: $0) }
        let revision = UUID().uuidString

        var imageNames: [String] = []
        var stagedFileNames: [String] = []
        var photoRecords: [PostComposerDraftPhoto] = []
        for photo in photos {
            let originalName = originalImageFileName(draftID: resolvedID, photoID: photo.id, revision: revision)
            let previewName = previewImageFileName(draftID: resolvedID, photoID: photo.id, revision: revision)
            stagedFileNames.append(contentsOf: [originalName, previewName])
            guard
                write(photo.originalImage, fileName: originalName, draftID: resolvedID),
                write(photo.image, fileName: previewName, draftID: resolvedID)
            else {
                removeFiles(stagedFileNames)
                return nil
            }
            imageNames.append(previewName)
            photoRecords.append(PostComposerDraftPhoto(
                id: photo.id,
                originalFileName: originalName,
                previewFileName: previewName,
                source: photo.source,
                edits: photo.edits,
                processingState: photo.processingState,
                processingError: photo.processingError,
                createdAt: photo.createdAt
            ))
        }

        let draft = PostComposerDraft(
            schemaVersion: currentSchemaVersion,
            id: resolvedID,
            step: step,
            status: status,
            vibeTags: selectedVibes,
            latitude: selectedLocation?.coordinate.latitude,
            longitude: selectedLocation?.coordinate.longitude,
            placeName: selectedLocation?.placeName,
            address: selectedLocation?.address,
            isCustomName: selectedLocation?.isCustomName ?? false,
            imageFileNames: imageNames,
            photoRecords: photoRecords,
            updatedAt: Date()
        )

        guard let encoded = try? JSONEncoder().encode(draft) else {
            SpotLogger.log(PostDraftStoreLogs.draftWriteFailed, details: ["draftId": resolvedID, "error": "encode_failed"])
            removeFiles(allImageFileNames(in: draft))
            return nil
        }
        do {
            try encoded.write(to: draftFileURL(for: resolvedID), options: .atomic)
        } catch {
            SpotLogger.log(PostDraftStoreLogs.draftWriteFailed, details: ["draftId": resolvedID, "error": error.localizedDescription])
            removeFiles(allImageFileNames(in: draft))
            return nil
        }

        upsertSummary(for: draft)
        if let previousDraft {
            removeFiles(allImageFileNames(in: previousDraft))
        }
        return resolvedID
    }

    static func loadDraft(id: String) -> PostComposerDraftLoadResult? {
        guard let raw = try? Data(contentsOf: draftFileURL(for: id)) else {
            SpotLogger.log(PostDraftStoreLogs.draftReadFailed, details: ["draftId": id])
            return nil
        }
        guard let draft = try? JSONDecoder().decode(PostComposerDraft.self, from: raw) else {
            SpotLogger.log(PostDraftStoreLogs.draftDecodeFailed, details: ["draftId": id])
            return nil
        }

        let photos = restorePhotos(from: draft)

        var location: LocationData?
        if
            let lat = draft.latitude,
            let lon = draft.longitude,
            let placeName = draft.placeName
        {
            location = LocationData(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                placeName: placeName,
                address: draft.address,
                isCustomName: draft.isCustomName
            )
        }

        return PostComposerDraftLoadResult(draft: draft, photos: photos, location: location)
    }

    static func loadAutosavedDraft() -> PostComposerDraftLoadResult? {
        loadDraft(id: autosavedDraftID)
    }

    static func loadPreviewImage(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        let url = draftsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return image
    }

    static func deleteDraft(id: String) {
        if let draft = (try? Data(contentsOf: draftFileURL(for: id))).flatMap({ try? JSONDecoder().decode(PostComposerDraft.self, from: $0) }) {
            for fileName in allImageFileNames(in: draft) {
                let url = draftsDirectory.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? FileManager.default.removeItem(at: draftFileURL(for: id))

        var summaries = loadIndex()
        summaries.removeAll { $0.id == id }
        saveIndex(summaries)
        SpotLogger.log(PostDraftStoreLogs.draftDeleted, details: ["draftId": id])
    }

    static func clearAutosave() {
        deleteDraft(id: autosavedDraftID)
    }

    static func clearAll() {
        for draft in loadIndex() {
            deleteDraft(id: draft.id)
        }
    }
}

private extension PostDraftStore {
    static func write(_ image: UIImage, fileName: String, draftID: String) -> Bool {
        guard let data = image.spot_jpegDataOpaque(compressionQuality: 0.88) else { return false }
        do {
            try data.write(to: draftsDirectory.appendingPathComponent(fileName), options: .atomic)
            return true
        } catch {
            SpotLogger.log(PostDraftStoreLogs.draftImageWriteFailed, details: [
                "draftId": draftID,
                "fileName": fileName,
                "error": error.localizedDescription
            ])
            return false
        }
    }

    static func restorePhotos(from draft: PostComposerDraft) -> [PostComposerPhoto] {
        if let records = draft.photoRecords {
            return records.map { record in
                let original = loadImage(fileName: record.originalFileName, draftID: draft.id)
                let preview = loadImage(fileName: record.previewFileName, draftID: draft.id)
                let fallback = preview ?? original ?? unavailablePlaceholder()
                let renderedAfterInterruptedSave: UIImage? = {
                    guard let original,
                          preview == nil || record.processingState == .processing else { return nil }
                    return try? PostPhotoProcessor.render(original: original, edits: record.edits)
                }()
                let restoredState: PostComposerPhotoProcessingState
                let restoredError: String?
                if original == nil {
                    restoredState = .unavailable
                    restoredError = "This photo is no longer available on this device."
                } else if record.processingState == .processing || preview == nil {
                    restoredState = renderedAfterInterruptedSave == nil ? .failed : .ready
                    restoredError = renderedAfterInterruptedSave == nil
                        ? "We couldn’t prepare this photo."
                        : nil
                } else {
                    restoredState = record.processingState
                    restoredError = record.processingError
                }
                return PostComposerPhoto(
                    id: record.id,
                    image: renderedAfterInterruptedSave ?? fallback,
                    originalImage: original ?? fallback,
                    source: record.source,
                    edits: record.edits,
                    processingState: restoredState,
                    processingError: restoredError,
                    createdAt: record.createdAt
                )
            }
        }
        return draft.imageFileNames.map { fileName in
            guard let image = loadImage(fileName: fileName, draftID: draft.id) else {
                return PostComposerPhoto(
                    image: unavailablePlaceholder(),
                    source: .legacyDraft,
                    processingState: .unavailable,
                    processingError: "This photo is no longer available on this device."
                )
            }
            return PostComposerPhoto(image: image, source: .legacyDraft)
        }
    }

    static func loadImage(fileName: String, draftID: String) -> UIImage? {
        let url = draftsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            SpotLogger.log(PostDraftStoreLogs.draftImageReadFailed, details: [
                "draftId": draftID,
                "fileName": fileName,
                "reason": "read_or_decode_failed"
            ])
            return nil
        }
        return image
    }

    static func unavailablePlaceholder() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240), format: format).image { context in
            UIColor.secondarySystemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
        }
    }

    static func allImageFileNames(in draft: PostComposerDraft) -> [String] {
        if let records = draft.photoRecords {
            return records.flatMap { [$0.originalFileName, $0.previewFileName] }
        }
        return draft.imageFileNames
    }

    static func removeFiles(_ fileNames: [String]) {
        for fileName in Set(fileNames) {
            try? FileManager.default.removeItem(at: draftsDirectory.appendingPathComponent(fileName))
        }
    }

    static func upsertSummary(for draft: PostComposerDraft) {
        let step: PostComposerDraftStep = switch draft.step {
        case 1: .photos
        case 2: .location
        default: .vibes
        }
        let summary = PostComposerDraftSummary(
            id: draft.id,
            status: draft.status,
            previewImageFileName: draft.imageFileNames.first,
            placeName: draft.placeName,
            vibeTags: draft.vibeTags,
            updatedAt: draft.updatedAt,
            step: step
        )

        var summaries = loadIndex()
        summaries.removeAll { $0.id == draft.id }
        summaries.append(summary)
        summaries.sort(by: { $0.updatedAt > $1.updatedAt })
        saveIndex(summaries)
    }
}
