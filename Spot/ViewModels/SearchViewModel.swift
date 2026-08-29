//
//  SearchViewModel.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation
@MainActor
final class SearchViewModel: ObservableObject {
    enum Segment: String, CaseIterable { case users = "Users", locations = "Locations", vibes = "Vibes" }

    @Published var query: String = "" {
        didSet {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            SpotLogger.log(SearchViewModelLogs.searchQueryChanged, details: ["query": q])
            debouncer.schedule { Task { await self.performSearch() } }
        }
    }
    @Published var segment: Segment = .users {
        didSet {
            SpotLogger.log(SearchViewModelLogs.searchSegmentSwitched, details: ["segment": segment.rawValue])
            // Clear current results and any open grid when switching tabs
            users = []
            locations = []
            vibes = []
            gridTitle = nil
            gridIsVibe = false
            gridSpots = []
            lastGridDoc = nil
            hasMoreGrid = true
            loadSearchHistory()
            Task {
                if self.segment == .vibes {
                    await self.loadAllVibeTags()
                }
                await self.performSearch(force: true)
            }
        }
    }

    // Sections
    @Published var users: [[String: Any]] = []
    @Published var locations: [String] = []
    @Published var vibes: [String] = []
    
    // Search History
    @Published var searchHistory: [SearchHistoryManager.SearchHistoryItem] = []
    @Published var showHistory: Bool = false

    // Grids
    @Published var gridTitle: String?
    @Published var gridIsVibe: Bool = false
    @Published var gridSpots: [Spot] = []
    private var lastGridDoc: String?
    @Published var isLoadingGrid = false
    @Published var hasMoreGrid = true
    // Advanced filters (Pro)
    @Published var allVibeTags: [String] = []
    @Published var selectedVibeFilters: Set<String> = []
    @Published var gridVibeFilters: [String]? // Published so view can display active filters
    private var gridLocationFilter: String? // Track location when filtering by vibes

    private let debouncer = Debouncer(interval: 0.3)
    private let service = SearchService.shared
    private let historyManager = SearchHistoryManager.shared

    func clear() {
        users = []
        locations = []
        vibes = []
        gridTitle = nil
        gridIsVibe = false
        gridSpots = []
        lastGridDoc = nil
        hasMoreGrid = true
        gridVibeFilters = nil
        gridLocationFilter = nil
        selectedVibeFilters.removeAll()
        showHistory = false
    }
    
    // MARK: - Search History
    
    func loadSearchHistory() {
        let historyType: SearchHistoryManager.SearchHistoryItem.SearchType
        switch segment {
        case .users: historyType = .user
        case .locations: historyType = .location
        case .vibes: historyType = .vibe
        }
        searchHistory = historyManager.getHistory(for: historyType)
        SpotLogger.log(SearchViewModelLogs.searchHistoryLoaded, details: [
            "segment": segment.rawValue,
            "count": searchHistory.count
        ])
    }
    
    func addToHistory(query: String, displayText: String) {
        let historyType: SearchHistoryManager.SearchHistoryItem.SearchType
        switch segment {
        case .users: historyType = .user
        case .locations: historyType = .location
        case .vibes: historyType = .vibe
        }
        
        let item = SearchHistoryManager.SearchHistoryItem(
            type: historyType,
            query: query,
            displayText: displayText
        )
        historyManager.addItem(item)
        loadSearchHistory()
    }
    
    func removeHistoryItem(withId id: UUID) {
        historyManager.removeItem(withId: id)
        loadSearchHistory()
    }
    
    func clearSearchHistory() {
        let historyType: SearchHistoryManager.SearchHistoryItem.SearchType
        switch segment {
        case .users: historyType = .user
        case .locations: historyType = .location
        case .vibes: historyType = .vibe
        }
        historyManager.clearHistory(for: historyType)
        loadSearchHistory()
        SpotLogger.log(SearchViewModelLogs.searchHistoryCleared, details: ["segment": segment.rawValue])
    }
    
    func selectHistoryItem(_ item: SearchHistoryManager.SearchHistoryItem) {
        query = item.query
        showHistory = false
        
        // Trigger the appropriate action based on type
        Task {
            switch item.type {
            case .user:
                // For users, just perform the search
                await performSearch(force: true)
            case .location:
                await openLocation(item.query)
            case .vibe:
                await openVibe(item.query)
            }
        }
    }

    func performSearch(force: Bool = false) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Show history when query is empty
        if q.isEmpty {
            showHistory = true
            loadSearchHistory()
            
            if segment == .vibes {
                if allVibeTags.isEmpty {
                    await loadAllVibeTags()
                }
                vibes = allVibeTags
                SpotLogger.log(SearchViewModelLogs.searchVibesSuggestions, details: ["count": vibes.count, "defaultList": true])
            } else {
                users = []
                locations = []
                vibes = []
            }
            return
        }
        
        // Hide history when actively searching
        showHistory = false

        switch segment {
        case .users:
            do {
                users = try await service.searchUsers(prefix: q).items
                SpotLogger.log(SearchViewModelLogs.searchUsersResults, details: ["count": users.count])
            } catch { }
        case .locations:
            do {
                locations = try await service.searchLocationSuggestions(prefix: q)
                SpotLogger.log(SearchViewModelLogs.searchLocationsSuggestions, details: ["count": locations.count])
            } catch { }
        case .vibes:
            do {
                vibes = try await service.searchVibeSuggestions(prefix: q)
                SpotLogger.log(SearchViewModelLogs.searchVibesSuggestions, details: ["count": vibes.count])
            } catch { }
        }
    }
    
    // MARK: Grid flows
    func openLocation(_ name: String) async {
        // Add to history
        addToHistory(query: name, displayText: name.capitalized)
        
        gridTitle = name
        gridIsVibe = false
        gridLocationFilter = name
        gridVibeFilters = nil
        users = []
        locations = []
        vibes = []
        gridSpots = []
        lastGridDoc = nil
        hasMoreGrid = true
        showHistory = false
        SpotLogger.log(SearchViewModelLogs.openLocationGrid, details: ["name": name])
        await loadMoreGrid()
    }

    func openVibe(_ tag: String) async {
        // Add to history
        addToHistory(query: tag, displayText: tag.capitalized)
        
        gridTitle = tag
        gridIsVibe = true
        users = []
        locations = []
        vibes = []
        gridSpots = []
        lastGridDoc = nil
        hasMoreGrid = true
        gridVibeFilters = nil
        showHistory = false
        SpotLogger.log(SearchViewModelLogs.openVibeGrid, details: ["tag": tag])
        await loadMoreGrid(isVibe: true)
    }

    func openVibeFilters(_ tags: [String]) async {
        guard !tags.isEmpty else { return }
        gridTitle = "Vibes"
        gridIsVibe = true
        users = []
        locations = []
        vibes = []
        gridSpots = []
        lastGridDoc = nil
        hasMoreGrid = true
        gridVibeFilters = tags
        SpotLogger.log(SearchViewModelLogs.openMultiVibeGrid, details: ["count": tags.count])
        await loadMoreGrid(isVibe: true)
    }

    func loadMoreGrid(isVibe: Bool = false) async {
        guard !isLoadingGrid, hasMoreGrid, let title = gridTitle else { return }
        isLoadingGrid = true
        defer { isLoadingGrid = false }
        do {
            let lower = title.lowercased()
            var accumulated: [Spot] = []
            var attempts = 0
            var nextCursor = lastGridDoc
            var set = Set(gridSpots.compactMap { $0.id })
            while accumulated.count < 24 && attempts < 5 {
                attempts += 1
                let page: SearchPage<Spot>
                // Check for location + vibe combination (Pro feature)
                if let locationFilter = gridLocationFilter, let filters = gridVibeFilters, !filters.isEmpty {
                    page = try await service.fetchSpotsByLocationAndVibes(locationFilter.lowercased(), vibeLowers: filters.map { $0.lowercased() }, last: nextCursor)
                } else if isVibe, let filters = gridVibeFilters, !filters.isEmpty {
                    page = try await service.fetchSpotsByVibes(filters.map { $0.lowercased() }, last: nextCursor)
                } else {
                    page = try await (isVibe ? service.fetchSpotsByVibe(lower, last: nextCursor) : service.fetchSpotsByLocation(lower, last: nextCursor))
                }
                nextCursor = page.lastDocument
                let newUnique = page.items.filter { spot in
                    let id = spot.id ?? UUID().uuidString
                    if set.contains(id) { return false }
                    set.insert(id)
                    return true
                }
                accumulated.append(contentsOf: newUnique)
                if page.items.isEmpty || nextCursor == nil { break }
            }
            gridSpots.append(contentsOf: accumulated)
            lastGridDoc = nextCursor
            // `lastGridDoc` is the next server offset; nil means no further pages (see `SpotSearchDataSource`).
            hasMoreGrid = nextCursor != nil
            SpotLogger.log(SearchViewModelLogs.gridLoadedPage, details: [
                "pageCount": accumulated.count,
                "total": gridSpots.count,
                "hasMore": hasMoreGrid
            ])
        } catch {
            hasMoreGrid = false
            SpotLogger.log(SearchViewModelLogs.gridLoadFailed, details: ["error": error.localizedDescription])
        }
    }

    // MARK: Vibe tags source for filters
    func loadAllVibeTags() async {
        // Fetch custom tags from database
        let customTags = await VibeTagService.shared.fetchAll().map { $0.name }
        
        // Combine defaults + custom tags, remove duplicates, and sort
        let allTags = Array(Set(Constants.VibeTags.defaultTags + customTags)).sorted { $0.lowercased() < $1.lowercased() }
        allVibeTags = allTags
        SpotLogger.log(SearchViewModelLogs.loadedAllVibeTags, details: ["defaultCount": Constants.VibeTags.defaultTags.count, "customCount": customTags.count, "total": allTags.count])
    }

    func applySelectedVibeFilters() async {
        let tags = Array(selectedVibeFilters)
        // If we have a location filter active, preserve it and filter by vibes within that location
        if let locationFilter = gridLocationFilter, !tags.isEmpty {
            gridVibeFilters = tags
            gridSpots = []
            lastGridDoc = nil
            hasMoreGrid = true
            SpotLogger.log(SearchViewModelLogs.applyVibeFiltersToLocation, details: ["location": locationFilter, "vibes": tags])
            await loadMoreGrid(isVibe: false) // Not a pure vibe grid, but uses location+vibe combo
        } else if !tags.isEmpty {
            await openVibeFilters(tags)
        } else {
            // No tags selected, clear filters
            await clearFiltersAndReload()
        }
    }

    func clearFiltersAndReload() async {
        selectedVibeFilters.removeAll()
        gridVibeFilters = nil
        
        // If we have a location filter active, reload without vibe filters
        if let locationFilter = gridLocationFilter {
            gridSpots = []
            lastGridDoc = nil
            hasMoreGrid = true
            SpotLogger.log(SearchViewModelLogs.clearVibeFilters, details: ["location": locationFilter])
            await loadMoreGrid(isVibe: false)
        } else if gridIsVibe, let title = gridTitle {
            // If we're viewing a vibe grid, reload without multi-vibe filters
            gridSpots = []
            lastGridDoc = nil
            hasMoreGrid = true
            SpotLogger.log(SearchViewModelLogs.clearFiltersReloadingVibe, details: ["vibe": title])
            await loadMoreGrid(isVibe: true)
        }
        // Otherwise, grid will remain as-is (no filters were active)
    }
}
