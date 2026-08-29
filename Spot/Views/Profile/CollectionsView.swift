//
//  CollectionsView.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

struct CollectionsView: View {
    @State private var collections: [BookmarkCollection] = []
    @State private var isLoading = true
    @State private var newName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
                Text("Collections")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                    .frame(maxWidth: .infinity)
                Spacer().frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack(spacing: 8) {
                TextField("New collection name", text: $newName)
                    .foregroundColor(Constants.Colors.primary)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Constants.Colors.primary, lineWidth: 1))
                Button {
                    Task { await create() }
                } label: {
                    Text("Create")
                        .font(FontManager.primaryText())
                        .foregroundColor(Constants.Colors.buttonText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Constants.Colors.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!CollectionNamePolicy.canCreate(newName))
            }
            .padding(.horizontal, 16)

            if isLoading {
                ProgressView().padding(.top, 20)
            } else if collections.isEmpty {
                Text("No collections yet")
                    .font(FontManager.primaryText())
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            } else {
                List {
                    ForEach(collections) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.name)
                                .font(FontManager.primaryText())
                                .foregroundColor(Constants.Colors.primary)
                            Text("\(c.spotIds.count) spots")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer()
        }
        .background(Constants.Colors.background.ignoresSafeArea())
        .onAppear { Task { await load() } }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func load() async {
        isLoading = true
        do { collections = try await BookmarksCollectionsService.shared.listCollections() } catch { collections = [] }
        isLoading = false
    }

    private func create() async {
        let name = CollectionNamePolicy.normalized(newName)
        guard CollectionNamePolicy.canCreate(name) else { return }
        do {
            _ = try await BookmarksCollectionsService.shared.createCollection(name: name)
            newName = ""
            await load()
        } catch { }
    }
}

#Preview {
    CollectionsView()
}
