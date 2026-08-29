//
//  MapControlsOverlay.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import SwiftUI

/// Bottom edge (max Y) of the map filter pill row in `mapCanvas` space — drives drawer max height.
enum MapFilterPillRowBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        switch (value, nextValue()) {
        case (nil, nil): break
        case let (nil, .some(n)): value = n
        case (.some, nil): break
        case let (.some(v), .some(n)): value = max(v, n)
        }
    }
}

struct MapControlsOverlay: View {
    /// `nil` = filter pill row hidden (non-Pro). Provide a binding to show it.
    var filterState: Binding<SpotMapFilterState>?
    var availableVibeTags: [String]
    var onOpenVibePicker: () -> Void
    /// Recenter button visibility. `nil` hides the control entirely (e.g.,
    /// when location permission is denied and we don't want to pretend to
    /// offer the feature).
    var canRecenter: Bool
    var onRecenter: () -> Void
    /// Bottom inset reserved for the spot preview card so the recenter
    /// button sits above it instead of behind it.
    var bottomReservedHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Top: filter pill row (Pro only).
            if let filterState {
                VStack(spacing: 0) {
                    MapFilterPillRow(
                        state: filterState,
                        vibeTags: availableVibeTags,
                        onOpenVibePicker: onOpenVibePicker
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MapFilterPillRowBottomPreferenceKey.self,
                                value: proxy.frame(in: .named("mapCanvas")).maxY
                            )
                        }
                    )
                    Spacer(minLength: 0)
                }
                .accessibilityIdentifier("map.filterButton")
            }

            // Bottom-right: recenter button.
            if canRecenter {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        recenterButton
                            .padding(.trailing, Constants.Layout.Spacing.large)
                            .padding(.bottom, max(Constants.Layout.Spacing.large,
                                                  bottomReservedHeight + 12))
                    }
                }
            }
        }
        .allowsHitTesting(true)
    }

    private var recenterButton: some View {
        Button(action: onRecenter) {
            Image(systemName: "location.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Constants.Colors.buttonText)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(Constants.Colors.primary)
                )
                .overlay(
                    Circle().stroke(Constants.Colors.background, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.20), radius: 4, x: 0, y: 2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 2)
        .accessibilityLabel("Recenter map on my location")
        .accessibilityIdentifier("map.recenter")
    }
}

// MARK: - Preview

#Preview("Map controls – Pro w/ recenter") {
    let vibeTags = Constants.VibeTags.defaultTags
    return StatefulFilterState(initial: SpotMapFilterState(dimensions: [.following], vibeTags: [])) { binding in
        ZStack {
            Constants.Colors.accent.ignoresSafeArea()
            MapControlsOverlay(
                filterState: binding,
                availableVibeTags: vibeTags,
                onOpenVibePicker: {},
                canRecenter: true,
                onRecenter: {},
                bottomReservedHeight: 0
            )
        }
    }
}

#Preview("Map controls – non-Pro") {
    ZStack {
        Constants.Colors.accent.ignoresSafeArea()
        MapControlsOverlay(
            filterState: nil,
            availableVibeTags: [],
            onOpenVibePicker: {},
            canRecenter: true,
            onRecenter: {},
            bottomReservedHeight: 0
        )
    }
}

private struct StatefulFilterState<Content: View>: View {
    @State var value: SpotMapFilterState
    let content: (Binding<SpotMapFilterState>) -> Content
    init(initial: SpotMapFilterState, @ViewBuilder content: @escaping (Binding<SpotMapFilterState>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
