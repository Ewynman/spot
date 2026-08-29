//
//  ProfileMapView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct ProfileMapView: View {
    let spots: [Spot]
    var username: String = ""
    var avatarURL: String? = nil
    var isPro: Bool = false
    var markerOffset: CGFloat = Constants.MapDesign.selectedPinCameraLift

    @State private var cameraIntent: SharedSpotMapCameraIntent = .fitAll(animated: false)
    @State private var hasFitInitialPins: Bool = false

    private var onSpotTap: ((Spot) -> Void)?
    private var onDeleteSpot: ((Spot) -> Void)?
    private var onCollapseChange: ((Bool) -> Void)?
    private var onBackToProfile: (() -> Void)?

    init(
        spots: [Spot],
        username: String = "",
        avatarURL: String? = nil,
        isPro: Bool = false,
        onSpotTap: ((Spot) -> Void)? = nil,
        onDeleteSpot: ((Spot) -> Void)? = nil,
        onCollapseChange: ((Bool) -> Void)? = nil,
        onBackToProfile: (() -> Void)? = nil
    ) {
        self.spots = spots
        self.username = username
        self.avatarURL = avatarURL
        self.isPro = isPro
        self.onSpotTap = onSpotTap
        self.onDeleteSpot = onDeleteSpot
        self.onCollapseChange = onCollapseChange
        self.onBackToProfile = onBackToProfile
        _ = markerOffset
    }

    var body: some View {
        MapExperience(
            mode: .profile(
                username: username.isEmpty ? "Spots" : username,
                spotCount: spots.count,
                avatarURL: avatarURL,
                isPro: isPro
            ),
            spots: spots,
            cameraIntent: $cameraIntent,
            filter: .empty,
            savedSpotIds: [],
            likedSpotIds: [],
            followedUserIds: [],
            userMarker: nil,
            suppressDefaultUserDot: true,
            allowDelete: true,
            onRegionChanged: { _ in
                cameraIntent = .none
            },
            onSpotSelected: { spot in
                onSpotTap?(spot)
                onCollapseChange?(true)
            },
            onSpotDeselected: {
                onCollapseChange?(false)
            },
            onDeleteSpot: { spot in
                onDeleteSpot?(spot)
            },
            onBackFromProfile: {
                onBackToProfile?()
            }
        )
        .ignoresSafeArea()
        .onAppear {
            if !hasFitInitialPins {
                hasFitInitialPins = true
                cameraIntent = .fitAll(animated: false)
            }
        }
        .onChange(of: spotsSignature) { _, _ in
            cameraIntent = .fitAll(animated: true)
        }
        .background(Constants.Colors.background.ignoresSafeArea())
    }

    private var spotsSignature: String {
        spots.compactMap { $0.id }.joined(separator: ",")
    }
}

#Preview {
    ProfileMapView(spots: [
        Spot(id: "1", userId: "u1", username: "eddie",
             imageURL: "https://picsum.photos/seed/1/800/600", vibeTag: "View",
             latitude: 37.7749, longitude: -122.4194,
             locationName: "San Francisco", createdAt: Date()),
        Spot(id: "2", userId: "u1", username: "eddie",
             imageURL: "https://picsum.photos/seed/2/800/600", vibeTag: "Coffee",
             latitude: 34.0522, longitude: -118.2437,
             locationName: "Los Angeles", createdAt: Date())
    ], username: "eddie", isPro: true)
    .environmentObject(AuthViewModel())
}
