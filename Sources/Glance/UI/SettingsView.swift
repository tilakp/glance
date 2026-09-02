import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: GlanceSettings

    var body: some View {
        TabView {
            RhythmTab(settings: settings)
                .tabItem { Label("Rhythm", systemImage: "circle.dotted") }
            SmartPauseTab(settings: settings)
                .tabItem { Label("Smart Pause", systemImage: "pause.circle") }
            ActivitiesTab(settings: settings)
                .tabItem { Label("Activities", systemImage: "leaf") }
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 560, height: 430)
    }
}

// MARK: - Rhythm

private struct RhythmTab: View {
    @ObservedObject var settings: GlanceSettings

    var body: some View {
        Form {
            Section {
                Picker("Eye reminder every", selection: $settings.focusInterval) {
                    ForEach([10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(TimeInterval(minutes * 60))
                    }
                }
                Picker("Break duration", selection: $settings.breakDuration) {
                    ForEach([20, 30, 45, 60, 120, 300], id: \.self) { seconds in
                        Text(secondsLabel(seconds)).tag(TimeInterval(seconds))
                    }
                }
            } footer: {
                Text("The 20-20-20 guideline: every 20 minutes, look at something 20 feet away for 20 seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Respect my natural breaks", isOn: $settings.respectIdle)
                Picker("Away from the keyboard for", selection: $settings.idleResetThreshold) {
                    ForEach([2, 3, 5, 10], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(TimeInterval(minutes * 60))
                    }
                }
                .disabled(!settings.respectIdle)
            } footer: {
                Text("Stepping away already rests your eyes. Under a minute counts as thinking and still adds up; past a minute the timer holds; past the time below it starts over, so Glance does not remind you the moment you sit back down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func secondsLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) seconds" : "\(seconds / 60) minute\(seconds == 60 ? "" : "s")"
    }
}

// MARK: - Smart Pause

private struct SmartPauseTab: View {
    @ObservedObject var settings: GlanceSettings
    @State private var selection: String?

    var body: some View {
        Form {
            Section("Automatically wait when") {
                Toggle("Camera is active", isOn: $settings.pauseOnCamera)
                Toggle("Presenting or sharing a screen", isOn: $settings.pauseOnPresenting)
                Toggle("One of these apps is in front", isOn: $settings.pauseForApps)
            }

            Section {
                List(selection: $selection) {
                    ForEach(settings.pausedAppIDs, id: \.self) { id in
                        AppRow(bundleID: id)
                    }
                }
                .frame(height: 108)

                HStack {
                    Button("Add App…", action: addApp)
                    Button("Remove", action: removeSelected)
                        .disabled(selection == nil)
                    Spacer()
                }
            }
            .disabled(!settings.pauseForApps)

            Section {
                Picker("Then remind after", selection: $settings.postContextDelay) {
                    Text("Right away").tag(TimeInterval(0))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                }
            } footer: {
                Text("Screen time keeps counting during a call, and one break arrives shortly after it ends. Glance does not stack up the breaks you missed - it just makes sure you get the next one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }

        let added = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        settings.pausedAppIDs = Array(Set(settings.pausedAppIDs + added)).sorted {
            AppMonitor.displayName(for: $0) < AppMonitor.displayName(for: $1)
        }
    }

    private func removeSelected() {
        guard let selection else { return }
        settings.pausedAppIDs.removeAll { $0 == selection }
        self.selection = nil
    }
}

private struct AppRow: View {
    var bundleID: String

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    // Keeps rows aligned when the app is not installed.
                    Image(systemName: "app.dashed")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16, height: 16)
            Text(AppMonitor.displayName(for: bundleID))
        }
        .tag(bundleID)
    }

    private var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Activities

private struct ActivitiesTab: View {
    @ObservedObject var settings: GlanceSettings

    var body: some View {
        Form {
            Section {
                ForEach(BreakActivity.all) { activity in
                    Toggle(isOn: binding(for: activity)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                            Text(activity.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Glance rotates through the prompts you keep on, so the overlay stays worth reading.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for activity: BreakActivity) -> Binding<Bool> {
        Binding(
            get: { settings.enabledActivityIDs.contains(activity.id) },
            set: { isOn in
                var ids = settings.enabledActivityIDs
                if isOn {
                    guard !ids.contains(activity.id) else { return }
                    ids.append(activity.id)
                } else {
                    // Keep at least one, or breaks would have nothing to say.
                    guard ids.count > 1 else { return }
                    ids.removeAll { $0 == activity.id }
                }
                settings.enabledActivityIDs = ids
            }
        )
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var settings: GlanceSettings

    var body: some View {
        Form {
            Section {
                Toggle("Start Glance at login", isOn: $settings.launchAtLogin)
                Toggle("Reduce motion", isOn: $settings.reduceMotion)
            }

            Section("Privacy") {
                Text("Glance never records your camera, microphone, screen, or meetings, and nothing leaves your Mac. To know when to stay quiet it checks three things: whether any camera is switched on, which app is in front, and the size and layer of on-screen windows - enough to spot a slideshow or a screen share, never their contents.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
