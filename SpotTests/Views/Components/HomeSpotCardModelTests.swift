import Testing
@testable import Spot

@Suite("Home Spot card presentation")
struct HomeSpotCardModelTests {
    @Test func defaultsToPhotoAndTogglesDeterministically() {
        var model = HomeSpotCardModel(spotId: "a")

        #expect(model.face == .photo)
        let firstStarted = model.beginToggle()
        #expect(firstStarted)
        #expect(model.face == .map)
        let repeatedStarted = model.beginToggle()
        #expect(!repeatedStarted)

        model.completeToggle()
        #expect(model.face == .map)
        #expect(!model.isTransitioning)

        let secondStarted = model.beginToggle()
        #expect(secondStarted)
        #expect(model.face == .photo)
        model.completeToggle()
        #expect(model.face == .photo)
    }

    @Test func reuseResetsFaceAndTransition() {
        var model = HomeSpotCardModel(spotId: "a")
        let started = model.beginToggle()
        #expect(started)
        model.completeToggle()
        #expect(model.face == .map)

        model.reset(for: "b")

        #expect(model.spotId == "b")
        #expect(model.face == .photo)
        #expect(!model.isTransitioning)
    }

    @Test func reduceMotionSelectsCrossfade() {
        #expect(HomeSpotCardModel.transitionStyle(reduceMotion: false) == .flip3D)
        #expect(HomeSpotCardModel.transitionStyle(reduceMotion: true) == .crossfade)
    }
}
