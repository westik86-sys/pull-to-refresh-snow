import SwiftUI

@main
struct HomeStandaloneApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TestInAppView()
            }
        }
    }
}
