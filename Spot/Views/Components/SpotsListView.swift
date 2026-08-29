//
//  SpotsListView.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI

struct SpotsListView: View {
    let spots: [Spot]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(spots) { spot in
                    SpotCard(spot: spot)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(hex: "F5F3EF"))
    }
}
