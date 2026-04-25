import SwiftUI

// MARK: - Settings Screen

struct SettingsScreen: View {
    @State private var showUpgradeAlert = false
    @State private var showRestoreAlert = false
    @Environment(\.upgradeAction) private var upgradeAction
    @Environment(\.restoreAction) private var restoreAction

    var body: some View {
        List {
            Section("Purchase") {
                SettingsRow("Upgrade", tinted: true, trailingLabel: "$4.99", action: {
                    Task {
                        let productAvailable = await upgradeAction()
                        if !productAvailable { showUpgradeAlert = true }
                    }
                })
                SettingsRow("Restore Purchase", action: {
                    Task {
                        let found = await restoreAction()
                        if !found { showRestoreAlert = true }
                    }
                })
            }

            Section("Support / Legal") {
                SettingsRow("Contact Support", destination: URL(string: "mailto:auditools-support@proton.me"))
                SettingsRow("Privacy Policy", destination: URL(string: "https://raspy-lake-e0d2.akashi-uopeople.workers.dev/TrackingCheck/privacy-policy"))
                SettingsRow("Terms of Use", destination: URL(string: "https://raspy-lake-e0d2.akashi-uopeople.workers.dev/TrackingCheck/terms-of-use"))
            }

            Section("App") {
                NavigationLink(destination: AboutScreen()) {
                    Text("About")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upgrade", isPresented: $showUpgradeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("In-app purchase isn't available yet. Check back soon.")
        }
        .alert("Restore Purchase", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No previous purchase found.")
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let title: String
    var tinted: Bool = false
    var trailingLabel: String? = nil
    var destination: URL? = nil
    var action: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    init(_ title: String, tinted: Bool = false, trailingLabel: String? = nil, destination: URL? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.tinted = tinted
        self.trailingLabel = trailingLabel
        self.destination = destination
        self.action = action
    }

    var body: some View {
        Button {
            if let action { action() } else if let url = destination { openURL(url) }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(tinted ? Color.accentColor : .primary)
                Spacer()
                if let label = trailingLabel {
                    Text(label)
                        .font(.system(size: 17))
                        .foregroundColor(tinted ? Color.accentColor : .secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.78))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About Screen

struct AboutScreen: View {
    var body: some View {
        List {
            Section {
                LabeledContent("App", value: "Tracking Check")
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        guard !v.isEmpty else { return "—" }
        return b.isEmpty ? v : "\(v) (\(b))"
    }
}

// MARK: - Previews

#Preview("Settings") {
    NavigationStack {
        SettingsScreen()
    }
}

#Preview("About") {
    NavigationStack {
        AboutScreen()
    }
}
