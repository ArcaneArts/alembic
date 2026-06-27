import AppKit
import SwiftUI

/// Settings pane for the non-intrusive update flow. Shows the current status,
/// offers manual Check Now / Update Now actions, and the automatic-check toggle.
/// Backed by `AlembicUpdatesBridge.shared.state` and the shared pane helpers
/// (`paneHeader`, `settingRow`, `AlembicSettingsCard`) defined alongside the
/// other settings panes.
struct AlembicSettingsUpdatesPane: View {
    @ObservedObject private var updates: UpdatesBridgeState = AlembicUpdatesBridge.shared.state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(
                    title: "Updates",
                    description: "Alembic never interrupts you about updates. When one is available you'll see a yellow dot here and on the settings button."
                )

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            statusIcon
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(statusTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(statusDetail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }

                        if updates.isDownloading {
                            ProgressView(value: max(0, min(1, updates.downloadProgress)))
                                .progressViewStyle(.linear)
                        }

                        if updates.status == "error", let message: String = updates.errorMessage {
                            Text(message)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider().opacity(0.2)

                        HStack(spacing: 8) {
                            if updates.updateAvailable {
                                Button {
                                    AlembicUpdatesBridge.shared.install { result in
                                        if result.ok {
                                            // Helper is launched and waiting on this
                                            // process; quitting lets it swap the bundle.
                                            NSApp.terminate(nil)
                                        }
                                    }
                                } label: {
                                    Label("Update Now", systemImage: "arrow.down.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .disabled(updates.isDownloading)
                            }

                            Button {
                                AlembicUpdatesBridge.shared.checkNow { _ in }
                            } label: {
                                Label("Check Now", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(updates.isBusy)

                            if !updates.releaseUrl.isEmpty {
                                Button {
                                    if let url: URL = URL(string: updates.releaseUrl) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Label("Release page", systemImage: "safari")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                    }
                }

                AlembicSettingsCard {
                    settingRow(
                        title: "Check for updates automatically",
                        description: "When on, Alembic checks once shortly after launch and shows a dot if an update is available. When off, nothing happens until you press Check Now."
                    ) {
                        Toggle(
                            "",
                            isOn: Binding<Bool>(
                                get: { updates.autoCheckEnabled },
                                set: { next in
                                    AlembicUpdatesBridge.shared.setAutoCheck(next) { _ in }
                                }
                            )
                        )
                        .labelsHidden()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onAppear { AlembicUpdatesBridge.shared.requestSnapshot() }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch updates.status {
        case "updateAvailable", "downloading":
            AlembicUpdateDot(size: 11)
        case "error":
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
        case "checking":
            ProgressView()
                .controlSize(.small)
        default:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)
        }
    }

    private var statusTitle: String {
        switch updates.status {
        case "updateAvailable": return "Update available"
        case "downloading": return "Downloading update…"
        case "checking": return "Checking for updates…"
        case "error": return "Update check failed"
        case "upToDate": return "Up to date"
        default:
            return updates.currentVersion.isEmpty
                ? "Alembic"
                : "Alembic \(updates.currentVersion)"
        }
    }

    private var statusDetail: String {
        switch updates.status {
        case "updateAvailable":
            return "Alembic \(updates.currentVersion) → \(updates.latestVersion ?? "?")"
        case "downloading":
            let pct: Int = Int((max(0, min(1, updates.downloadProgress)) * 100).rounded())
            let target: String = updates.latestVersion ?? ""
            return "Installing \(target) — \(pct)%"
        case "checking":
            return "Contacting GitHub…"
        case "upToDate":
            return "Alembic \(updates.currentVersion)\(lastCheckedSuffix)"
        case "error":
            return "Alembic \(updates.currentVersion)\(lastCheckedSuffix)"
        default:
            return "Current version\(lastCheckedSuffix)"
        }
    }

    private var lastCheckedSuffix: String {
        guard updates.lastCheckedMs > 0 else { return "" }
        let date: Date = Date(timeIntervalSince1970: Double(updates.lastCheckedMs) / 1000.0)
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return " · checked \(formatter.string(from: date))"
    }
}
