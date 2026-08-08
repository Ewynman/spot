import Foundation

/// Whether dismissing the map spot drawer should restore the pre-select viewport.
enum MapDrawerDismissRestore {
    static func shouldRestoreViewport(after reason: MapDrawerDismissReason) -> Bool {
        switch reason {
        case .mapMoved:
            return false
        default:
            return true
        }
    }
}
