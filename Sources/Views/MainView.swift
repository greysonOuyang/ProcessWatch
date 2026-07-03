import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("概览", systemImage: "gauge") }

            ProcessListView(settings: model.settings)
                .tabItem { Label("进程", systemImage: "list.bullet.rectangle") }

            HistoryView(history: model.history)
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }

            SettingsView(settings: model.settings, loginItem: model.loginItem)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .frame(minWidth: 1080, minHeight: 640)
    }
}
