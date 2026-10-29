import ServiceManagement
import SwiftUI
import UsageCore

/// Launch at login through the app's own login item (macOS 13+).
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval
    @Published private(set) var failed = false

    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setEnabled(_ desired: Bool) {
        do {
            if desired { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            failed = false
        } catch {
            failed = true
        }
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    var notificationsChanged: (Bool) -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["AIUsageBarBuildId"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        Form {
            Picker("Show", selection: $store.settings.displayMode) {
                Text("Left").tag(UsageDisplayMode.left)
                Text("Used").tag(UsageDisplayMode.used)
            }
            .pickerStyle(.segmented)

            Toggle("Launch at login", isOn: Binding(
                get: { loginItem.enabled },
                set: { loginItem.setEnabled($0) }))
            if loginItem.needsApproval {
                Text("Allow AI Usage Bar in System Settings → General → Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if loginItem.failed {
                Text("macOS did not change the login item. Move the app to Applications and try again.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Toggle("Notify when less than 20% and 5% is left", isOn: Binding(
                get: { store.settings.notificationsEnabled },
                set: { store.settings.notificationsEnabled = $0; notificationsChanged($0) }))

            Section {
                List {
                    ForEach(store.settings.providerOrder, id: \.self) { provider in
                        HStack {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            Toggle(UsageFormat.providerName(provider), isOn: Binding(
                                get: { !store.settings.hiddenInMenuBar.contains(provider) },
                                set: { shown in
                                    if shown { store.settings.hiddenInMenuBar.remove(provider) }
                                    else { store.settings.hiddenInMenuBar.insert(provider) }
                                }))
                        }
                    }
                    .onMove { store.settings.move(fromOffsets: $0, toOffset: $1) }
                }
                .frame(height: 96)
            } header: {
                Text("Providers")
            } footer: {
                Text("Drag to reorder. Unchecked providers stay in the menu but leave the menu bar title.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Text("Credentials stay in your Keychain. AI Usage Bar only reads them.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Version \(version)")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loginItem.refresh() }
    }
}
