import SwiftUI

/// Root navigation view that adapts between tab bar (iPhone) and sidebar (iPad/Mac).
struct AdaptiveRootView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        SidebarNavigationView()
        #else
        if horizontalSizeClass == .regular {
            SidebarNavigationView()
        } else {
            TabNavigationView()
        }
        #endif
    }
}
