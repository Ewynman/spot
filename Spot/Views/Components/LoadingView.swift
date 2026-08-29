//
//  LoadingView.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        }
        .background(Color(hex: "F5F3EF"))
    }
}
