//
//  SearchHistoryManagerTests.swift
//  SpotTests
//
//  Comprehensive unit tests for SearchHistoryManager.
//

import Foundation
import Testing
@testable import Spot

@MainActor
struct SearchHistoryManagerTests {
    
    // Helper to clear UserDefaults before each test
    func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "search_history_v1")
    }
    
    @Test func defaultHistoryIsEmpty() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        let history = manager.getHistory()
        #expect(history.isEmpty)
    }
    
    @Test func addItemStoresInHistory() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "new york",
            displayText: "New York"
        )
        
        manager.addItem(item)
        let history = manager.getHistory()
        
        #expect(history.count == 1)
        #expect(history[0].query == "new york")
        #expect(history[0].displayText == "New York")
        #expect(history[0].type == .location)
    }
    
    @Test func addMultipleItemsMaintainsOrder() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        let item3 = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John Doe"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        manager.addItem(item3)
        
        let history = manager.getHistory()
        
        #expect(history.count == 3)
        #expect(history[0].query == "john")
        #expect(history[1].query == "chill")
        #expect(history[2].query == "nyc")
    }
    
    @Test func addDuplicateQueryRemovesOldEntry() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "new york",
            displayText: "New York"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        let item3 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "new york",
            displayText: "New York City"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        manager.addItem(item3)
        
        let history = manager.getHistory()
        
        #expect(history.count == 2)
        #expect(history[0].query == "new york")
        #expect(history[0].displayText == "New York City")
        #expect(history[1].query == "chill")
    }
    
    @Test func addDuplicateQueryCaseInsensitive() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "New York",
            displayText: "New York"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "new york",
            displayText: "NEW YORK"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        
        let history = manager.getHistory()
        
        #expect(history.count == 1)
        #expect(history[0].displayText == "NEW YORK")
    }
    
    @Test func addItemEnforcesMaxLimit() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        for i in 0..<25 {
            let item = SearchHistoryManager.SearchHistoryItem(
                type: .location,
                query: "location\(i)",
                displayText: "Location \(i)"
            )
            manager.addItem(item)
        }
        
        let history = manager.getHistory()
        
        #expect(history.count == 20)
        #expect(history[0].query == "location24")
        #expect(history[19].query == "location5")
    }
    
    @Test func removeItemByIdRemovesCorrectItem() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        
        let historyBefore = manager.getHistory()
        #expect(historyBefore.count == 2)
        
        manager.removeItem(withId: item1.id)
        
        let historyAfter = manager.getHistory()
        #expect(historyAfter.count == 1)
        #expect(historyAfter[0].id == item2.id)
    }
    
    @Test func removeNonExistentIdDoesNothing() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        manager.addItem(item)
        
        let historyBefore = manager.getHistory()
        #expect(historyBefore.count == 1)
        
        manager.removeItem(withId: UUID())
        
        let historyAfter = manager.getHistory()
        #expect(historyAfter.count == 1)
    }
    
    @Test func clearAllHistoryRemovesAllItems() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        let item3 = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John"
        )
        
        manager.addItem(item1)
        manager.addItem(item2)
        manager.addItem(item3)
        
        #expect(manager.getHistory().count == 3)
        
        manager.clearAllHistory()
        
        #expect(manager.getHistory().isEmpty)
    }
    
    @Test func clearHistoryByTypeRemovesOnlyThatType() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let location1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let location2 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "la",
            displayText: "Los Angeles"
        )
        let vibe = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        let user = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John"
        )
        
        manager.addItem(location1)
        manager.addItem(vibe)
        manager.addItem(location2)
        manager.addItem(user)
        
        #expect(manager.getHistory().count == 4)
        
        manager.clearHistory(for: .location)
        
        let remaining = manager.getHistory()
        #expect(remaining.count == 2)
        #expect(remaining.contains { $0.type == .vibe })
        #expect(remaining.contains { $0.type == .user })
        #expect(!remaining.contains { $0.type == .location })
    }
    
    @Test func getHistoryByTypeFiltersCorrectly() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let location = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let vibe = SearchHistoryManager.SearchHistoryItem(
            type: .vibe,
            query: "chill",
            displayText: "Chill"
        )
        let user = SearchHistoryManager.SearchHistoryItem(
            type: .user,
            query: "john",
            displayText: "John"
        )
        
        manager.addItem(location)
        manager.addItem(vibe)
        manager.addItem(user)
        
        let locationHistory = manager.getHistory(for: .location)
        let vibeHistory = manager.getHistory(for: .vibe)
        let userHistory = manager.getHistory(for: .user)
        
        #expect(locationHistory.count == 1)
        #expect(locationHistory[0].type == .location)
        
        #expect(vibeHistory.count == 1)
        #expect(vibeHistory[0].type == .vibe)
        
        #expect(userHistory.count == 1)
        #expect(userHistory[0].type == .user)
    }
    
    @Test func historyItemsAreSortedByTimestamp() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let now = Date()
        let item1 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "old",
            displayText: "Old",
            timestamp: now.addingTimeInterval(-100)
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "recent",
            displayText: "Recent",
            timestamp: now
        )
        let item3 = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "middle",
            displayText: "Middle",
            timestamp: now.addingTimeInterval(-50)
        )
        
        manager.addItem(item1)
        manager.addItem(item3)
        manager.addItem(item2)
        
        let history = manager.getHistory()
        
        #expect(history[0].query == "recent")
        #expect(history[1].query == "middle")
        #expect(history[2].query == "old")
    }
    
    @Test func searchHistoryItemEquality() {
        let item1 = SearchHistoryManager.SearchHistoryItem(
            id: UUID(),
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        let item2 = SearchHistoryManager.SearchHistoryItem(
            id: item1.id,
            type: .location,
            query: "nyc",
            displayText: "NYC",
            timestamp: item1.timestamp
        )
        let item3 = SearchHistoryManager.SearchHistoryItem(
            id: UUID(),
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        
        #expect(item1 == item2)
        #expect(item1 != item3)
    }
    
    @Test func searchTypeEnumRawValues() {
        #expect(SearchHistoryManager.SearchHistoryItem.SearchType.user.rawValue == "user")
        #expect(SearchHistoryManager.SearchHistoryItem.SearchType.location.rawValue == "location")
        #expect(SearchHistoryManager.SearchHistoryItem.SearchType.vibe.rawValue == "vibe")
    }
    
    @Test func historyPersistsAcrossInstances() {
        clearUserDefaults()
        let manager = SearchHistoryManager.shared
        
        let item = SearchHistoryManager.SearchHistoryItem(
            type: .location,
            query: "nyc",
            displayText: "NYC"
        )
        manager.addItem(item)
        
        let history1 = manager.getHistory()
        #expect(history1.count == 1)
        
        let history2 = SearchHistoryManager.shared.getHistory()
        #expect(history2.count == 1)
        #expect(history2[0].query == "nyc")
    }
}
