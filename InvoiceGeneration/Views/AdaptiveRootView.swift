import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Root navigation view that adapts between tab bar (iPhone) and sidebar (iPad/Mac).
struct AdaptiveRootView: View {
    var body: some View {
        #if os(macOS)
        SidebarNavigationView()
        #else
        // Choose the layout by device idiom, not horizontal size class.
        // Large iPhones (Plus/Max) report a `.regular` width in landscape, which
        // previously swapped the whole tree to the iPad sidebar on rotation —
        // tearing down the tab navigation, resetting it to the home screen, and
        // presenting a different detail view. iPhones always use the tab bar.
        if UIDevice.current.userInterfaceIdiom == .pad {
            SidebarNavigationView()
        } else {
            TabNavigationView()
        }
        #endif
    }
}
