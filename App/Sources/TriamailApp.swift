import SwiftUI

@main
struct TriamailApp: App {
    @State private var model = AppModel()

    init() {
        _ = Updater.shared
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                // List (280) + mail (360) + side pane (320), at their minimum widths.
                .frame(minWidth: 960, minHeight: 560)
                .environment(model)
        }
        .windowToolbarStyle(.unified)
        .commands { UpdateCommands() }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
