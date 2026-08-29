//
//  SearchService.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

final class SearchService {
    static let shared = SearchService()
    private init() {}

    private let fs = SpotSearchDataSource()
    private let privacy = AuthorPrivacyCache.shared

    // MARK: - Async/Await API (preferred)

    func searchUsers(prefix: String, last: String? = nil) async throws -> SearchPage<[String: Any]> {
        try await fs.searchUsers(prefix: prefix, last: last)
    }

    func searchLocationSuggestions(prefix: String) async throws -> [String] {
        try await fs.searchLocationSuggestions(prefix: prefix)
    }

    func searchVibeSuggestions(prefix: String) async throws -> [String] {
        try await fs.searchVibeSuggestions(prefix: prefix)
    }

    func fetchSpotsByLocation(_ locationLower: String, last: String? = nil) async throws -> SearchPage<Spot> {
        let page = try await fs.fetchSpotsByLocation(locationLower, last: last)
        let filtered = await privacy.filter(spots: page.items)
        return SearchPage(items: filtered, lastDocument: page.lastDocument)
    }

    func fetchSpotsByVibe(_ vibeLower: String, last: String? = nil) async throws -> SearchPage<Spot> {
        let page = try await fs.fetchSpotsByVibe(vibeLower, last: last)
        let filtered = await privacy.filter(spots: page.items)
        return SearchPage(items: filtered, lastDocument: page.lastDocument)
    }

    func fetchSpotsByVibes(_ vibeLowers: [String], last: String? = nil) async throws -> SearchPage<Spot> {
        let page = try await fs.fetchSpotsByVibes(vibeLowers, last: last)
        let filtered = await privacy.filter(spots: page.items)
        return SearchPage(items: filtered, lastDocument: page.lastDocument)
    }

    func fetchSpotsByLocationAndVibes(_ locationLower: String, vibeLowers: [String], last: String? = nil) async throws -> SearchPage<Spot> {
        let page = try await fs.fetchSpotsByLocationAndVibes(locationLower, vibeLowers: vibeLowers, last: last)
        let filtered = await privacy.filter(spots: page.items)
        return SearchPage(items: filtered, lastDocument: page.lastDocument)
    }

    // MARK: - Callback API (legacy / UI)

    func searchUsers(prefix: String, last: String? = nil, completion: @escaping (Result<SearchPage<[String: Any]>, Error>) -> Void) {
        Task { [weak self] in
            guard self != nil else { return }
            do {
                let page = try await self?.fs.searchUsers(prefix: prefix, last: last)
                completion(.success(page ?? SearchPage(items: [], lastDocument: nil)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func searchLocationSuggestions(prefix: String, completion: @escaping (Result<[String], Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let items = try await self.fs.searchLocationSuggestions(prefix: prefix)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func searchVibeSuggestions(prefix: String, completion: @escaping (Result<[String], Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let items = try await self.fs.searchVibeSuggestions(prefix: prefix)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchSpotsByLocation(_ locationLower: String, last: String? = nil, completion: @escaping (Result<SearchPage<Spot>, Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await self.fs.fetchSpotsByLocation(locationLower, last: last)
                let filtered = await self.privacy.filter(spots: page.items)
                completion(.success(SearchPage(items: filtered, lastDocument: page.lastDocument)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchSpotsByVibe(_ vibeLower: String, last: String? = nil, completion: @escaping (Result<SearchPage<Spot>, Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await self.fs.fetchSpotsByVibe(vibeLower, last: last)
                let filtered = await self.privacy.filter(spots: page.items)
                completion(.success(SearchPage(items: filtered, lastDocument: page.lastDocument)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchSpotsByVibes(_ vibeLowers: [String], last: String? = nil, completion: @escaping (Result<SearchPage<Spot>, Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await self.fs.fetchSpotsByVibes(vibeLowers, last: last)
                let filtered = await self.privacy.filter(spots: page.items)
                completion(.success(SearchPage(items: filtered, lastDocument: page.lastDocument)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchSpotsByLocationAndVibes(_ locationLower: String, vibeLowers: [String], last: String? = nil, completion: @escaping (Result<SearchPage<Spot>, Error>) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await self.fs.fetchSpotsByLocationAndVibes(locationLower, vibeLowers: vibeLowers, last: last)
                let filtered = await self.privacy.filter(spots: page.items)
                completion(.success(SearchPage(items: filtered, lastDocument: page.lastDocument)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
