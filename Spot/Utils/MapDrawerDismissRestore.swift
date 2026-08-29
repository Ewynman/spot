//
//  MapDrawerDismissRestore.swift
//  Spot
//
//  Created by Edward Wynman on 8/28/26.
//

import Foundation

/// Whether dismissing the map spot preview should restore the pre-select viewport.
/// PRD: deselect does not restore the previous camera — the user deliberately
/// navigated to the current region.
enum MapDrawerDismissRestore {
    static func shouldRestoreViewport(after reason: MapDrawerDismissReason) -> Bool {
        _ = reason
        return false
    }
}
