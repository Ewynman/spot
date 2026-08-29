//
//  MainTabView.swift
//  Spot
//
//  Created by Edward Wynman on 3/2/26.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        BottomTabNavigationView()
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.isAuthenticated = true
    return MainTabView().environmentObject(auth)
}
