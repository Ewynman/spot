//
//  SearchHistoryManager.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Manages persistent search history for users, locations, and vibes
final class SearchHistoryManager {
    static let shared = SearchHistoryManager()
    
    private let maxHistoryItems = 20
    private let userDefaultsKey = "search_history_v1"
    
    private init() {}
    
    // MARK: - Models
    
    struct SearchHistoryItem: Codable, Equatable {
        let id: UUID
        let type: SearchType
        let query: String
        let displayText: String
        let timestamp: Date
        
        enum SearchType: String, Codable {
            case user
            case location
            case vibe
        }
        
        init(id: UUID = UUID(), type: SearchType, query: String, displayText: String, timestamp: Date = Date()) {
            self.id = id
            self.type = type
            self.query = query
            self.displayText = displayText
            self.timestamp = timestamp
        }
    }
    
    // MARK: - Public API
    
    /// Retrieve all search history items, sorted by most recent first
    func getHistory() -> [SearchHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let items = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get history items filtered by type
    func getHistory(for type: SearchHistoryItem.SearchType) -> [SearchHistoryItem] {
        getHistory().filter { $0.type == type }
    }
    
    /// Add a new search history item
    func addItem(_ item: SearchHistoryItem) {
        var items = getHistory()
        
        // Remove duplicates (same type and query, case-insensitive)
        items.removeAll { existing in
            existing.type == item.type &&
            existing.query.lowercased() == item.query.lowercased()
        }
        
        // Add new item at the beginning
        items.insert(item, at: 0)
        
        // Trim to max size
        if items.count > maxHistoryItems {
            items = Array(items.prefix(maxHistoryItems))
        }
        
        saveHistory(items)
        SpotLogger.log(SearchHistoryLogs.itemAdded, details: [
            "type": item.type.rawValue,
            "query": item.query,
            "totalItems": items.count
        ])
    }
    
    /// Remove a specific history item by ID
    func removeItem(withId id: UUID) {
        var items = getHistory()
        items.removeAll { $0.id == id }
        saveHistory(items)
        SpotLogger.log(SearchHistoryLogs.itemRemoved, details: ["id": id.uuidString])
    }
    
    /// Clear all search history
    func clearAllHistory() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        SpotLogger.log(SearchHistoryLogs.historyCleared, details: [:])
    }
    
    /// Clear history for a specific search type
    func clearHistory(for type: SearchHistoryItem.SearchType) {
        var items = getHistory()
        items.removeAll { $0.type == type }
        saveHistory(items)
        SpotLogger.log(SearchHistoryLogs.historyTypeCleared, details: ["type": type.rawValue])
    }
    
    // MARK: - Private Helpers
    
    private func saveHistory(_ items: [SearchHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            SpotLogger.log(SearchHistoryLogs.saveFailed, details: [:])
            return
        }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

// MARK: - Logging

enum SearchHistoryLogs: SpotLog {
    case itemAdded
    case itemRemoved
    case historyCleared
    case historyTypeCleared
    case saveFailed
    
    var tag: String { "SearchHistoryManager" }
    
    var level: LogLevel { .debug }
    
    var message: String {
        switch self {
        case .itemAdded: return "Search history item added"
        case .itemRemoved: return "Search history item removed"
        case .historyCleared: return "All search history cleared"
        case .historyTypeCleared: return "Search history cleared for type"
        case .saveFailed: return "Failed to save search history"
        }
    }
}
