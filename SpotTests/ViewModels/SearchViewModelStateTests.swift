//
//  SearchViewModelStateTests.swift
//  SpotTests
//
//  Created By: Wynman, Edward
//  Date: 04/27/2026
//
//  Pure state-transition coverage for SearchViewModel.
//
//  SearchViewModel is welded to `SearchService.shared` and triggers a
//  debounced async `performSearch()` on `query`/`segment` mutations, so
//  these tests deliberately avoid mutating those fields. They guard
//  initial state, manual reset paths, and filter-list mutations that do
//  not initiate network calls.
//
//  Updated to include search history feature tests.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct SearchViewModelStateTests {
    
    func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "search_history_v1")
    }

    @Test func defaultStateIsEmpty() {
        let vm = SearchViewModel()
        #expect(vm.query == "")
        #expect(vm.segment == .users)
        #expect(vm.users.isEmpty)
        #expect(vm.locations.isEmpty)
        #expect(vm.vibes.isEmpty)
        #expect(vm.gridTitle == nil)
        #expect(vm.gridIsVibe == false)
        #expect(vm.gridSpots.isEmpty)
        #expect(vm.isLoadingGrid == false)
        #expect(vm.hasMoreGrid == true)
        #expect(vm.allVibeTags.isEmpty)
        #expect(vm.selectedVibeFilters.isEmpty)
        #expect(vm.gridVibeFilters == nil)
        #expect(vm.searchHistory.isEmpty)
        #expect(vm.showHistory == false)
    }

    @Test func clearResetsEverySection() {
        let vm = SearchViewModel()
        vm.users = [["id": "u1"]]
        vm.locations = ["NYC"]
        vm.vibes = ["Chill"]
        vm.gridTitle = "NYC"
        vm.gridIsVibe = true
        vm.gridSpots = [SpotTestHelpers.makeSpot(id: "g1")]
        vm.gridVibeFilters = ["Chill"]
        vm.selectedVibeFilters = ["Chill"]
        vm.hasMoreGrid = false
        vm.showHistory = true

        vm.clear()

        #expect(vm.users.isEmpty)
        #expect(vm.locations.isEmpty)
        #expect(vm.vibes.isEmpty)
        #expect(vm.gridTitle == nil)
        #expect(vm.gridIsVibe == false)
        #expect(vm.gridSpots.isEmpty)
        #expect(vm.gridVibeFilters == nil)
        #expect(vm.selectedVibeFilters.isEmpty)
        #expect(vm.hasMoreGrid == true)
        #expect(vm.showHistory == false)
    }

    @Test func segmentEnumExposesUsersLocationsVibes() {
        let cases = SearchViewModel.Segment.allCases
        #expect(cases.contains(.users))
        #expect(cases.contains(.locations))
        #expect(cases.contains(.vibes))
        #expect(SearchViewModel.Segment.users.rawValue == "Users")
        #expect(SearchViewModel.Segment.locations.rawValue == "Locations")
        #expect(SearchViewModel.Segment.vibes.rawValue == "Vibes")
    }

    @Test func selectedVibeFiltersAreMutable() {
        let vm = SearchViewModel()
        vm.selectedVibeFilters.insert("Chill")
        vm.selectedVibeFilters.insert("Adventure")
        #expect(vm.selectedVibeFilters == ["Chill", "Adventure"])
        vm.selectedVibeFilters.remove("Chill")
        #expect(vm.selectedVibeFilters == ["Adventure"])
    }

    @Test func clearFiltersAndReloadIsNoopWhenNoActiveGrid() async {
        let vm = SearchViewModel()
        vm.selectedVibeFilters = ["Chill"]
        vm.gridVibeFilters = ["Chill"]
        // No location filter, no gridIsVibe true → nothing to reload.
        await vm.clearFiltersAndReload()
        #expect(vm.selectedVibeFilters.isEmpty)
        #expect(vm.gridVibeFilters == nil)
        #expect(vm.gridSpots.isEmpty)
    }

    @Test func applySelectedVibeFiltersWithEmptySetClearsFilters() async {
        let vm = SearchViewModel()
        vm.gridVibeFilters = ["Chill"]
        // No location filter, no spots → safe to call without networking.
        await vm.applySelectedVibeFilters()
        #expect(vm.selectedVibeFilters.isEmpty)
        #expect(vm.gridVibeFilters == nil)
    }
    
    // MARK: - Search History Tests
    
    @Test func loadSearchHistoryPopulatesForCorrectSegment() {
        clearUserDefaults()
        let vm = SearchViewModel()
        let manager = SearchHistoryManager.shared
        
        let locationItem = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let userItem = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John"
        )
        
        manager.addItem(locationItem)
        manager.addItem(userItem)
        
        vm.segment = .users
        vm.loadSearchHistory()
        #expect(vm.searchHistory.count == 1)
        #expect(vm.searchHistory[0].type == .user)
        
        vm.segment = .locations
        vm.loadSearchHistory()
        #expect(vm.searchHistory.count == 1)
        #expect(vm.searchHistory[0].type == .location)
        
        clearUserDefaults()
    }
    
    @Test func addToHistoryCreatesCorrectTypeBasedOnSegment() {
        clearUserDefaults()
        let vm = SearchViewModel()
        
        vm.segment = .locations
        vm.addToHistory(query: "nyc", displayText: "NYC")
        
        let history = SearchHistoryManager.shared.getHistory()
        #expect(history.count == 1)
        #expect(history[0].type == .location)
        #expect(history[0].query == "nyc")
        #expect(history[0].displayText == "NYC")
        
        clearUserDefaults()
    }
    
    @Test func removeHistoryItemRemovesCorrectItem() {
        clearUserDefaults()
        let vm = SearchViewModel()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "la",
            displayText: "LA"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        
        vm.segment = .locations
        vm.loadSearchHistory()
        #expect(vm.searchHistory.count == 2)
        
        vm.removeHistoryItem(withId: item1.id)
        #expect(vm.searchHistory.count == 1)
        #expect(vm.searchHistory[0].id == item2.id)
        
        clearUserDefaults()
    }
    
    @Test func clearSearchHistoryClearsOnlyCurrentSegmentType() {
        clearUserDefaults()
        let vm = SearchViewModel()
        let manager = SearchHistoryManager.shared
        
        let locationItem = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let userItem = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John"
        )
        
        manager.addItem(locationItem)
        manager.addItem(userItem)
        
        vm.segment = .locations
        vm.clearSearchHistory()
        
        let allHistory = manager.getHistory()
        #expect(allHistory.count == 1)
        #expect(allHistory[0].type == .user)
        
        clearUserDefaults()
    }
    
    @Test func selectHistoryItemSetsQueryAndHidesHistory() {
        clearUserDefaults()
        let vm = SearchViewModel()
        
        let item = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        
        vm.showHistory = true
        vm.selectHistoryItem(item)
        
        #expect(vm.query == "nyc")
        #expect(vm.showHistory == false)
        
        clearUserDefaults()
    }
    
    @Test func showHistoryDefaultsFalse() {
        let vm = SearchViewModel()
        #expect(vm.showHistory == false)
    }
    
    @Test func searchHistoryInitiallyEmpty() {
        clearUserDefaults()
        let vm = SearchViewModel()
        #expect(vm.searchHistory.isEmpty)
        clearUserDefaults()
    }
}

