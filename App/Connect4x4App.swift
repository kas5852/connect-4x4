import SwiftUI
import ConnectUI

@main
struct Connect4x4App: App {
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            RootView().frame(minWidth: 390, minHeight: 760)
            #else
            RootView()
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 390, height: 844)
        #endif
    }
}
