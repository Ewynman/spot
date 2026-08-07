//
//  MapFilterControls.swift
//  Spot
//
//  Pro-only map filter pill row + bottom sheet. Hidden for non-Pro users
//  per Eddie's call. Pro users get a compact pill that opens a sheet to
//  toggle filter dimensions and pick vibe tags.
//
//  The filter pipeline is purely client-side (applied to already-fetched
//  visible spots). We never alter the viewport-driven Supabase RPC.
//

import SwiftUI

// MARK: - Pill row

/// Floating pill row anchored to the top of the map. Shown only when the
/// viewer is Pro. Tapping any pill toggles its dimension; tapping the
/// "Vibes" pill while active opens the vibe-tag picker sheet.
struct MapFilterPillRow: View {
    @Binding var state: SpotMapFilterState
    /// Available vibe tags (passed in so the row stays decoupled from
    /// Constants and tests can inject deterministic data).
    var vibeTags: [String]
    /// Called when the pill row wants to open the vibe picker sheet.
    var onOpenVibePicker: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SpotMapFilter.allCases) { dim in
                pill(for: dim)
            }
            if state.isActive {
                Button(action: clear) {
                    Text("Clear")
                        .font(FontManager.buttonText())
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule().fill(Constants.Colors.background.opacity(0.95))
                        )
                        .overlay(
                            Capsule().stroke(Constants.Colors.primary.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear map filters")
            }
        }
        .padding(.horizontal, Constants.Layout.Spacing.large)
        .padding(.top, Constants.Layout.Spacing.small)
    }

    @ViewBuilder
    private func pill(for dim: SpotMapFilter) -> some View {
        let active = state.dimensions.contains(dim)
        Button(action: { toggle(dim) }) {
            HStack(spacing: 6) {
                Image(systemName: dim.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(dim.label)
                    .font(FontManager.buttonText())
            }
            .foregroundColor(active ? Constants.Colors.buttonText : Constants.Colors.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule().fill(active ? Constants.Colors.primary : Constants.Colors.background.opacity(0.95))
            )
            .overlay(
                Capsule().stroke(Constants.Colors.primary.opacity(active ? 0 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dim.label) filter \(active ? "on" : "off")")
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private func toggle(_ dim: SpotMapFilter) {
        let shouldOpenVibePicker = state.toggling(dim)
        if state.dimensions.contains(dim) {
            SpotLogger.log(MapFilterLogs.filterApplied, details: ["dim": dim.rawValue])
        } else {
            SpotLogger.log(MapFilterLogs.filterCleared, details: ["dim": dim.rawValue])
        }
        if shouldOpenVibePicker {
            onOpenVibePicker()
        }
    }

    private func clear() {
        state = .empty
        SpotLogger.log(MapFilterLogs.filterCleared, details: ["dim": "all"])
    }
}

// MARK: - Vibe sheet

struct MapVibeFilterSheet: View {
    @Binding var state: SpotMapFilterState
    var vibeTags: [String]
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.Spacing.medium) {
            HStack {
                Text("Filter by vibe")
                    .font(FontManager.sectionHeader())
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Constants.Colors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close vibe filter sheet")
            }

            ScrollView {
                let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(vibeTags, id: \.self) { tag in
                        let active = state.vibeTags.contains(tag)
                        Button(action: { toggle(tag) }) {
                            Text(tag)
                                .font(FontManager.buttonText())
                                .foregroundColor(active ? Constants.Colors.buttonText : Constants.Colors.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Capsule().fill(active ? Constants.Colors.primary : Constants.Colors.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? [.isSelected] : [])
                    }
                }
            }
        }
        .padding(Constants.Layout.Spacing.large)
        .background(Constants.Colors.background.ignoresSafeArea())
    }

    private func toggle(_ tag: String) {
        state.togglingVibeTag(tag)
        SpotLogger.log(MapFilterLogs.filterApplied, details: [
            "dim": SpotMapFilter.vibe.rawValue,
            "tag": tag,
            "active": state.vibeTags.contains(tag)
        ])
    }
}

// MARK: - Previews

#Preview("Filter pill row – inactive") {
    StatefulPreview(SpotMapFilterState.empty) { state in
        MapFilterPillRow(state: state, vibeTags: Constants.VibeTags.defaultTags, onOpenVibePicker: {})
            .padding()
            .background(Constants.Colors.background)
    }
}

#Preview("Filter pill row – active") {
    StatefulPreview(SpotMapFilterState(dimensions: [.saved, .following], vibeTags: [])) { state in
        MapFilterPillRow(state: state, vibeTags: Constants.VibeTags.defaultTags, onOpenVibePicker: {})
            .padding()
            .background(Constants.Colors.background)
    }
}

#Preview("Vibe filter sheet") {
    StatefulPreview(SpotMapFilterState(dimensions: [.vibe], vibeTags: ["Hidden Gem"])) { state in
        MapVibeFilterSheet(
            state: state,
            vibeTags: Constants.VibeTags.defaultTags,
            onClose: {}
        )
    }
}

/// Tiny helper that lets previews use `@State`-style bindings without
/// boilerplate. Local to this file so it doesn't pollute the global
/// preview surface.
private struct StatefulPreview<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content
    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }
    var body: some View { content($value) }
}
