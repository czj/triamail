import SwiftUI

@main
struct TriamailApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}
