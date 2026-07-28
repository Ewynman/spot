//
//  LocationSelectionViewLogs.swift
//  Spot
//
//  Log definitions for LocationSelectionView.
//

import Foundation

enum LocationSelectionViewLogs: SpotLog {
    case loadingNearbyPlaces
    case noCurrentLocationAvailable
    case gotCurrentLocation
    case nearbyPlaceSearchFailed
    case foundNearbyPlaces
    case searchingPlaces
    case anchoredPlaceMatched
    case placesQueryFailed
    case searchPlacesFailed
    case foundLocalSearchResults
    case noLocalResultsRetryingGlobal
    case foundGlobalSearchResults
    case userSelectedLocation
    case reverseGeocodeFailed
    case upsertPlaceFailed
    case blockedCustomPlaceSkipUpsert

    var tag: String { "LocationSelectionView" }
    var level: LogLevel {
        switch self {
        case .loadingNearbyPlaces: return .debug
        case .noCurrentLocationAvailable: return .debug
        case .gotCurrentLocation: return .info
        case .nearbyPlaceSearchFailed: return .error
        case .foundNearbyPlaces: return .debug
        case .searchingPlaces: return .debug
        case .anchoredPlaceMatched: return .info
        case .placesQueryFailed: return .debug
        case .searchPlacesFailed: return .error
        case .foundLocalSearchResults: return .debug
        case .noLocalResultsRetryingGlobal: return .debug
        case .foundGlobalSearchResults: return .debug
        case .userSelectedLocation: return .info
        case .reverseGeocodeFailed: return .debug
        case .upsertPlaceFailed: return .debug
        case .blockedCustomPlaceSkipUpsert: return .debug
        }
    }
    var message: String {
        switch self {
        case .loadingNearbyPlaces: return "Loading nearby places"
        case .noCurrentLocationAvailable: return "No current location available, using default region"
        case .gotCurrentLocation: return "Got current location"
        case .nearbyPlaceSearchFailed: return "Failed to search nearby places"
        case .foundNearbyPlaces: return "Found nearby places"
        case .searchingPlaces: return "Searching for places with query"
        case .anchoredPlaceMatched: return "Anchored place matched"
        case .placesQueryFailed: return "Places query failed"
        case .searchPlacesFailed: return "Failed to search places"
        case .foundLocalSearchResults: return "Found local search results"
        case .noLocalResultsRetryingGlobal: return "No local results; retrying with global span"
        case .foundGlobalSearchResults: return "Found global search results"
        case .userSelectedLocation: return "User selected location"
        case .reverseGeocodeFailed: return "Reverse geocode failed"
        case .upsertPlaceFailed: return "Upsert place failed"
        case .blockedCustomPlaceSkipUpsert: return "Blocked custom place at confirm, skipping upsert"
        }
    }
}
