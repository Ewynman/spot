//
//  UserLocationAnnotationView.swift
//  Spot
//
//  Branded user-location avatar marker. Replaces Apple's default blue dot
//  on the discovery map. Renders the viewer's profile picture in a clean
//  circle with a green ring (regular) or gold ring (Pro). Falls back to
//  initials, then to a branded dot, when the avatar isn't available.
//
//  Important memory rule: the avatar image is fetched **once** per session
//  via the shared `MapAvatarImageCache` (defined below) and held as a
//  small UIImage. We never re-decode it on every map update.
//

import UIKit
import MapKit
import SwiftUI

// MARK: - Annotation model

/// Annotation backing the user-location marker. Coordinate is updated by
/// the discovery map as `LocationManager.userLocation` changes.
final class SpotUserLocationAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var profileImageURL: String?
    var username: String?
    var kind: SpotMapUserKind

    init(coordinate: CLLocationCoordinate2D,
         profileImageURL: String?,
         username: String?,
         kind: SpotMapUserKind) {
        self.coordinate = coordinate
        self.profileImageURL = profileImageURL
        self.username = username
        self.kind = kind
        super.init()
    }
}

// MARK: - View

final class UserLocationAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "UserLocationMarker"

    private let ringLayer = CAShapeLayer()
    private let avatarLayer = CALayer()
    private let initialsLabel = UILabel()
    private let fallbackSymbolView = UIImageView()
    private let haloLayer = CAShapeLayer()

    private var loadedAvatarURL: String?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        let size = Constants.MapDesign.avatarMarkerSize
        let haloSize: CGFloat = size + 16
        let frame = CGRect(x: 0, y: 0, width: haloSize, height: haloSize)
        self.frame = frame
        self.backgroundColor = .clear
        self.canShowCallout = false
        self.isOpaque = false

        // Halo (always visible at low opacity; pulses while location is updating)
        haloLayer.frame = frame
        haloLayer.path = UIBezierPath(ovalIn: frame.insetBy(dx: 1, dy: 1)).cgPath
        haloLayer.fillColor = UIColor(Constants.Colors.mapAvatarHalo).cgColor
        haloLayer.opacity = 0
        layer.addSublayer(haloLayer)

        // Ring (green or gold based on kind)
        let ringFrame = CGRect(
            x: (haloSize - size) / 2,
            y: (haloSize - size) / 2,
            width: size,
            height: size
        )
        ringLayer.frame = ringFrame
        ringLayer.path = UIBezierPath(ovalIn: ringLayer.bounds).cgPath
        ringLayer.fillColor = UIColor(Constants.Colors.background).cgColor
        ringLayer.strokeColor = UIColor(Constants.Colors.mapAvatarRing).cgColor
        ringLayer.lineWidth = Constants.MapDesign.avatarRingWidth
        layer.addSublayer(ringLayer)

        // Avatar circle (image content)
        let avatarInset = Constants.MapDesign.avatarRingWidth + 1.5
        avatarLayer.frame = ringFrame.insetBy(dx: avatarInset, dy: avatarInset)
        avatarLayer.cornerRadius = avatarLayer.bounds.height / 2
        avatarLayer.masksToBounds = true
        avatarLayer.backgroundColor = UIColor(Constants.Colors.accent).cgColor
        layer.addSublayer(avatarLayer)

        // Initials fallback
        initialsLabel.frame = CGRect(origin: .zero, size: avatarLayer.bounds.size)
        initialsLabel.textAlignment = .center
        initialsLabel.font = .systemFont(ofSize: size * 0.40, weight: .bold)
        initialsLabel.textColor = UIColor(Constants.Colors.primary)
        initialsLabel.adjustsFontSizeToFitWidth = true
        initialsLabel.minimumScaleFactor = 0.6
        addSubview(initialsLabel)
        initialsLabel.frame = avatarLayer.frame

        // Generic fallback for accounts without a profile photo or username.
        // A recognizable silhouette is intentionally used instead of the
        // previous tiny dot, which could look like a missing map marker.
        fallbackSymbolView.image = UIImage(systemName: "person.fill")
        fallbackSymbolView.tintColor = UIColor(Constants.Colors.primary)
        fallbackSymbolView.contentMode = .scaleAspectFit
        fallbackSymbolView.frame = avatarLayer.frame.insetBy(dx: 7, dy: 7)
        addSubview(fallbackSymbolView)
        showFallback(for: nil)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarLayer.contents = nil
        loadedAvatarURL = nil
        showFallback(for: nil)
        ringLayer.strokeColor = UIColor(Constants.Colors.mapAvatarRing).cgColor
        haloLayer.opacity = 0
    }

    /// Configure the marker for `annotation`. Idempotent — repeated calls
    /// with the same URL don't re-fetch the avatar.
    func configure(with annotation: SpotUserLocationAnnotation) {
        // Ring color
        switch annotation.kind {
        case .regular:
            ringLayer.strokeColor = UIColor(Constants.Colors.mapAvatarRing).cgColor
        case .pro:
            ringLayer.strokeColor = UIColor(Constants.Colors.proGold).cgColor
        }

        // Avatar — normalize whitespace / scheme-less URLs; only skip a
        // re-fetch when the *same normalized* URL already decoded into the
        // layer (a failed fetch must be allowed to retry when configure
        // runs again after auth loads the URL).
        if let normalized = Self.normalizeProfileURLString(annotation.profileImageURL),
           let url = URL(string: normalized) {
            if loadedAvatarURL == normalized, avatarLayer.contents != nil {
                initialsLabel.isHidden = true
                fallbackSymbolView.isHidden = true
                return
            }
            avatarLayer.contents = nil
            showFallback(for: annotation.username)
            loadedAvatarURL = normalized
            MapAvatarImageCache.shared.fetch(url) { [weak self] image in
                guard let self,
                      self.loadedAvatarURL == normalized else {
                    return
                }
                guard let image else {
                    self.loadedAvatarURL = nil
                    self.avatarLayer.contents = nil
                    self.showFallback(for: annotation.username)
                    SpotLogger.log(MapMarkerLogs.userMarkerAvatarFallback, details: [
                        "reason": "decode_or_network_failed",
                        "urlLength": normalized.count
                    ])
                    return
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.avatarLayer.contents = image.cgImage
                self.avatarLayer.contentsGravity = .resizeAspectFill
                self.initialsLabel.isHidden = true
                self.fallbackSymbolView.isHidden = true
                CATransaction.commit()
                SpotLogger.log(MapMarkerLogs.userMarkerAvatarLoaded, details: [
                    "scheme": url.scheme ?? "none",
                    "urlLength": normalized.count
                ])
            }
        } else {
            loadedAvatarURL = nil
            avatarLayer.contents = nil
            showFallback(for: annotation.username)
            SpotLogger.log(MapMarkerLogs.userMarkerAvatarFallback, details: [
                "username": annotation.username ?? "nil"
            ])
        }
    }

    private func showFallback(for username: String?) {
        switch Self.fallbackContent(from: username) {
        case .initials(let initials):
            initialsLabel.text = initials
            initialsLabel.isHidden = false
            fallbackSymbolView.isHidden = true
        case .personSymbol:
            initialsLabel.isHidden = true
            fallbackSymbolView.isHidden = false
        }
    }

    /// Trim and lightly normalize profile URLs from Supabase (handles
    /// `//host/path`, stray spaces, etc.) without logging the raw string.
    private static func normalizeProfileURLString(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("//") {
            s = "https:" + s
        }
        if URL(string: s) != nil { return s }
        let spaced = s.replacingOccurrences(of: " ", with: "%20")
        if URL(string: spaced) != nil { return spaced }
        return nil
    }

    /// Toggle the soft pulse halo (used while the device is acquiring or
    /// updating a fresh location fix).
    func setHalo(active: Bool) {
        let target: Float = active ? 1 : 0
        guard haloLayer.opacity != target else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = haloLayer.opacity
        anim.toValue = target
        anim.duration = 0.35
        haloLayer.add(anim, forKey: "haloFade")
        haloLayer.opacity = target
    }

    /// Returns initials from a username. "Eddie Wynman" → "EW", "eddie" → "E".
    static func initials(from username: String?) -> String {
        guard case .initials(let initials) = fallbackContent(from: username) else { return "·" }
        return initials
    }

    static func fallbackContent(from username: String?) -> UserLocationMarkerFallbackContent {
        guard let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .personSymbol
        }
        let parts = username.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if parts.isEmpty { return .personSymbol }
        if parts.count == 1 { return .initials(String(parts[0].prefix(1)).uppercased()) }
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last = parts.last.map { String($0.prefix(1)) } ?? ""
        return .initials((first + last).uppercased())
    }
}

enum UserLocationMarkerFallbackContent: Equatable {
    case initials(String)
    case personSymbol
}

// MARK: - Avatar image cache

/// Tiny in-memory image cache for the user-location avatar marker.
/// Bounded to a single image (the viewer's avatar) so the map can never
/// accumulate avatar memory across sessions.
final class MapAvatarImageCache {
    static let shared = MapAvatarImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private let queue = DispatchQueue(label: "com.spot.map.avatar-cache", qos: .userInitiated)

    private init() {
        cache.countLimit = 4
    }

    func fetch(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        queue.async { [weak self] in
            URLSession.shared.dataTask(with: url) { data, _, error in
                guard error == nil,
                      let data,
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                self?.cache.setObject(image, forKey: url as NSURL)
                DispatchQueue.main.async { completion(image) }
            }.resume()
        }
    }

    /// Drop the entire cache. Called on sign-out.
    func clear() {
        cache.removeAllObjects()
    }
}
