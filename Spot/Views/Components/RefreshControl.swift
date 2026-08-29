//
//  RefreshControl.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI

struct RefreshControl: View {
    let coordinateSpace: CoordinateSpace
    let onRefresh: () -> Void

    @State private var isRefreshing = false
    private let triggerOffset: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let midY = geo.frame(in: coordinateSpace).midY
            Color.clear
                .onChange(of: midY) { _, newValue in
                    if newValue > triggerOffset && !isRefreshing {
                        isRefreshing = true
                        onRefresh()
                    } else if newValue < 0 && isRefreshing {
                        isRefreshing = false
                    }
                }
            VStack {
                if isRefreshing {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
        }
        .frame(height: 1)
        .padding(.top, -50)
        .allowsHitTesting(false)
    }
}
