//
//  SpotPhotoPinSourceTests.swift
//  SpotTests
//
//  Locks down the image-URL resolution rule the photo preview marker
//  relies on: prefer `thumbnailURL`, fall back to `imageURL`, ignore
//  whitespace-only strings, and never crash on malformed input. This is
//  the seam that decides whether a spot renders as a photo pin or falls
//  back to the branded teardrop, so its contract is critical.
//

import Foundation
import MapKit
import Testing
@testable import Spot

struct SpotPhotoPinSourceTests {

    private func makeSpot(
        thumbnailURL: String? = nil,
        imageURL: String? = nil
    ) -> Spot {
        Spot(
            id: "s1",
            imageURL: imageURL,
            thumbnailURL: thumbnailURL
        )
    }

    @Test func prefersThumbnailWhenBothPresent() {
        let spot = makeSpot(
            thumbnailURL: "https://cdn.example.com/thumb.jpg",
            imageURL: "https://cdn.example.com/full.jpg"
        )
        #expect(SpotPhotoPinSource.imageURL(for: spot)?.absoluteString == "https://cdn.example.com/thumb.jpg")
    }

    @Test func fallsBackToImageURLWhenThumbnailMissing() {
        let spot = makeSpot(imageURL: "https://cdn.example.com/full.jpg")
        #expect(SpotPhotoPinSource.imageURL(for: spot)?.absoluteString == "https://cdn.example.com/full.jpg")
    }

    @Test func returnsNilWhenBothMissing() {
        #expect(SpotPhotoPinSource.imageURL(for: makeSpot()) == nil)
    }

    @Test func returnsNilForWhitespaceOnlyURL() {
        let spot = makeSpot(thumbnailURL: "   \n", imageURL: nil)
        #expect(SpotPhotoPinSource.imageURL(for: spot) == nil)
    }

    @Test func returnsNilForEmptyStringURL() {
        let spot = makeSpot(thumbnailURL: "", imageURL: "")
        #expect(SpotPhotoPinSource.imageURL(for: spot) == nil)
    }
}

struct SpotAnnotationZoomTests {

    @Test func zoomLevelForWorldSpanIsNearZero() {
        let region = MKCoordinateRegion(
            center: .init(latitude: 0, longitude: 0),
            span: .init(latitudeDelta: 360, longitudeDelta: 360)
        )
        let z = SpotAnnotationZoom.approximateZoomLevel(for: region)
        #expect(z >= 0)
        #expect(z <= 0.1)
    }

    @Test func zoomLevelForCitySpanIsInMidRange() {
        // ~city block scale
        let region = MKCoordinateRegion(
            center: .init(latitude: 40.7128, longitude: -74.006),
            span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        let z = SpotAnnotationZoom.approximateZoomLevel(for: region)
        #expect(z > 12)
        #expect(z < 16)
    }

    @Test func zoomLevelForZeroSpanIsBounded() {
        let region = MKCoordinateRegion(
            center: .init(latitude: 0, longitude: 0),
            span: .init(latitudeDelta: 0, longitudeDelta: 0)
        )
        // 0 span would normally divide-by-zero; helper clamps to a small
        // positive value so analytics never emit `inf` / `NaN`.
        let z = SpotAnnotationZoom.approximateZoomLevel(for: region)
        #expect(z.isFinite)
    }

    @Test func zoomLevelIsRoundedToOneDecimal() {
        let region = MKCoordinateRegion(
            center: .init(latitude: 0, longitude: 0),
            span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        let z = SpotAnnotationZoom.approximateZoomLevel(for: region)
        // Value is already at one decimal precision.
        #expect((z * 10).rounded() / 10 == z)
    }
}
