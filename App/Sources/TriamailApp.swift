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
                .frame(minWidth: MainWindowLayout.windowMin, minHeight: 560)
                .environment(model)
        }
        .windowToolbarStyle(.unified)
        .commands {
            UpdateCommands()
            SidebarCommands()
            MailboxCommands()
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
