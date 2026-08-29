//
//  SearchView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = SearchViewModel()
    @State private var path: [String] = []
    @FocusState private var focused: Bool
    @State private var selectedGridSpot: Spot?
    @State private var showFilters: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Constants.Colors.primary)
                    TextField(
                        "",
                        text: $vm.query,
                        prompt: Text("Search users, locations, vibes")
                            .foregroundColor(Constants.Colors.primary.opacity(0.62))
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .font(.system(size: 16))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .tint(Constants.Colors.primary)
                        .onChange(of: focused) { _, newValue in
                            if newValue && vm.query.isEmpty {
                                vm.loadSearchHistory()
                                vm.showHistory = true
                            }
                        }
                    if !vm.query.isEmpty {
                        Button(action: {
                            vm.query = ""
                            vm.clear()
                            selectedGridSpot = nil
                            focused = false
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Constants.Colors.textPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(Constants.Colors.accent.opacity(0.55))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.Colors.primary, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Segments styled like homepage tabs (Users / Locations / Vibes)
                HStack(spacing: 32) {
                    ForEach(SearchViewModel.Segment.allCases, id: \.self) { seg in
                        VStack(spacing: 4) {
                            Text(seg.rawValue)
                                .font(FontManager.primaryText())
                                .fontWeight(vm.segment == seg ? .semibold : .regular)
                                .foregroundColor(vm.segment == seg ? Constants.Colors.primary : .gray)
                            Rectangle()
                                .fill(vm.segment == seg ? Constants.Colors.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { vm.segment = seg } }
                    }
                    Spacer()
                    // Show filter button for Pro users only while viewing a location grid
                    if authVM.isPro && (vm.gridTitle != nil && !vm.gridIsVibe) {
                        Button {
                            showFilters = true
                            Task { await vm.loadAllVibeTags() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text("Filter")
                            }
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Search History Section (shown when query is empty and history exists)
                        if vm.showHistory && !vm.searchHistory.isEmpty && vm.query.isEmpty {
                            searchHistorySection
                        }
                        
                        // Users tab only
                        if vm.segment == .users && !vm.query.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(vm.users.indices, id: \.self) { i in
                                    let u = vm.users[i]
                                    if let uid = u["uid"] as? String, !uid.isEmpty {
                                        NavigationLink(value: uid) {
                                            HStack(spacing: 12) {
                                                UserAvatar(urlString: u["profileImageURL"] as? String)
                                                Text((u["username"] as? String) ?? "")
                                                    .font(FontManager.primaryText())
                                                    .foregroundColor(Constants.Colors.primary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        HStack(spacing: 12) {
                                            UserAvatar(urlString: u["profileImageURL"] as? String)
                                            Text((u["username"] as? String) ?? "")
                                                .font(FontManager.primaryText())
                                                .foregroundColor(Constants.Colors.primary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                    }
                                }
                                if vm.users.isEmpty && !vm.query.isEmpty {
                                    Text("No users found")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Locations tab
                        if vm.segment == .locations && !vm.query.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(vm.locations, id: \.self) { name in
                                    Button { Task { await vm.openLocation(name) } } label: {
                                        Text(name.capitalized)
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 16)
                                }
                                if vm.locations.isEmpty && !vm.query.isEmpty {
                                    Text("No locations found")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Vibes tab
                        if vm.segment == .vibes && !vm.query.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(vm.vibes, id: \.self) { tag in
                                    Button { Task { await vm.openVibe(tag) } } label: {
                                        VibeChip(text: tag.capitalized)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 16)
                                }
                                if vm.vibes.isEmpty && !vm.query.isEmpty {
                                    Text("No vibes found")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Grid when a location or vibe chosen
                        if let title = vm.gridTitle {
                            Divider().padding(.horizontal, 16)
                            HStack(spacing: 8) {
                                if vm.gridIsVibe {
                                    VibeChip(text: title.capitalized)
                                } else {
                                    Text(title.capitalized).font(FontManager.sectionHeader())
                                }
                                // Show active vibe filters if any
                                if let filters = vm.gridVibeFilters, !filters.isEmpty {
                                    ForEach(filters.prefix(3), id: \.self) { tag in
                                        VibeChip(text: tag.capitalized)
                                    }
                                    if filters.count > 3 {
                                        Text("+\(filters.count - 3)")
                                            .font(FontManager.primaryText())
                                            .foregroundColor(Constants.Colors.primary)
                                    }
                                }
                                Spacer()
                            }
                            .foregroundColor(Constants.Colors.primary)
                            .padding(.horizontal, 16)

                            if let selectedGridSpot {
                                SpotCard(
                                    spot: selectedGridSpot,
                                    showUserInfo: false,
                                    userId: nil,
                                    onDelete: nil,
                                    source: "SearchGrid",
                                    backAction: { withAnimation { self.selectedGridSpot = nil } },
                                    backButtonText: "Back to search results"
                                )
                                .transition(.opacity)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 24)
                                        .onEnded { value in
                                            let didSwipeRight = value.translation.width > 70 || value.predictedEndTranslation.width > 120
                                            if didSwipeRight {
                                                withAnimation { self.selectedGridSpot = nil }
                                            }
                                        }
                                )
                            } else {
                                if vm.gridSpots.isEmpty && !vm.isLoadingGrid && !vm.hasMoreGrid {
                                    Text("No results found")
                                        .font(FontManager.primaryText())
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 32)
                                } else {
                                    SpotsGridView(spots: vm.gridSpots, onSpotTapped: { spot in
                                        selectedGridSpot = spot
                                    }, onLoadMore: {
                                        Task { await vm.loadMoreGrid(isVibe: vm.gridIsVibe) }
                                    })
                                    .frame(maxHeight: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: String.self) { userId in
                ProfileView(userId: userId, fromNavigationPush: true)
            }
            .background(Color(hex: "F5F3EF"))
        }
        .sheet(isPresented: $showFilters) {
            filtersSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainTabReselectSame)) { output in
            guard (output.userInfo?[SpotMainTabNotification.userInfoTabIndexKey] as? Int) == 3 else { return }
            path.removeAll()
            selectedGridSpot = nil
            showFilters = false
            focused = false
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Search History Section
extension SearchView {
    @ViewBuilder
    private var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                if !vm.searchHistory.isEmpty {
                    Button("Clear All") {
                        vm.clearSearchHistory()
                    }
                    .font(FontManager.primaryText())
                    .foregroundColor(Constants.Colors.primary)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            
            ForEach(vm.searchHistory, id: \.id) { item in
                HStack(spacing: 12) {
                    Image(systemName: historyIcon(for: item.type))
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    Button {
                        vm.selectHistoryItem(item)
                    } label: {
                        Text(item.displayText)
                            .font(FontManager.primaryText())
                            .foregroundColor(Constants.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        vm.removeHistoryItem(withId: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 8)
    }
    
    private func historyIcon(for type: SearchHistoryManager.SearchHistoryItem.SearchType) -> String {
        switch type {
        case .user: return "person.circle"
        case .location: return "mappin.circle"
        case .vibe: return "sparkles"
        }
    }
}

// MARK: - Filters Sheet
extension SearchView {
    @ViewBuilder
    private var filtersSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter by vibes")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                Button("Clear") {
                    vm.selectedVibeFilters.removeAll()
                    // Clear active filters and reload grid without filters
                    Task {
                        await vm.clearFiltersAndReload()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .font(FontManager.primaryText())
                .foregroundColor(Constants.Colors.primary)
            }
            .padding(.horizontal, 16)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vm.allVibeTags, id: \.self) { tag in
                        let selected = vm.selectedVibeFilters.contains(tag)
                        Button {
                            if selected { vm.selectedVibeFilters.remove(tag) } else { vm.selectedVibeFilters.insert(tag) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                Text(tag.capitalized)
                            }
                            .font(FontManager.primaryText())
                            .foregroundColor(selected ? .white : Constants.Colors.primary)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selected ? Constants.Colors.primary : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Constants.Colors.primary, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }

            Button {
                showFilters = false
                Task {
                    if vm.selectedVibeFilters.isEmpty {
                        await vm.clearFiltersAndReload()
                    } else {
                        await vm.applySelectedVibeFilters()
                    }
                }
            } label: {
                Text("Apply")
                    .font(FontManager.buttonText())
                    .foregroundColor(Constants.Colors.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 16)
        }
        .background(Color(hex: "F5F3EF"))
    }
}

struct UserAvatar: View {
    let urlString: String?
    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }
}

struct VibeChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(FontManager.primaryText())
            .foregroundColor(Constants.Colors.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Constants.Colors.accent)
            .cornerRadius(12)
    }
}

private struct SectionHeader: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(FontManager.sectionHeader())
            .foregroundColor(Constants.Colors.primary)
            .padding(.horizontal, 16)
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.isPro = true
    return SearchView()
        .environmentObject(auth)
}
