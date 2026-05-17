import AppKit
import SwiftUI

struct AlembicSpikeRootView: View {
    @ObservedObject var state: SpikeAppState
    @ObservedObject var repositoryState: RepositoryListBridgeState
    @ObservedObject var diagnosticsState: AlembicDiagnosticsState
    @ObservedObject var workspaceState: WorkspaceBridgeState
    @ObservedObject var workState: RepositoryWorkBridgeState
    @ObservedObject var settingsState: SettingsBridgeState
    @ObservedObject var accountsState: AccountsBridgeState
    let onRepositoryRefresh: () -> Void
    let onRepositoryRetry: () -> Void
    let onRepositoryOpen: (String) -> Void
    @State private var showDiagnostics: Bool = false
    @State private var showBootDetail: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        ZStack {
            AlembicSpikeBackground()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Divider().opacity(0.25)
                contentArea
                if showDiagnostics {
                    Divider().opacity(0.25)
                    AlembicDiagnosticsConsole(state: diagnosticsState)
                        .frame(height: 280)
                }
            }
        }
        .frame(
            minWidth: 760,
            idealWidth: 960,
            minHeight: 560,
            idealHeight: 720
        )
        .onReceive(NotificationCenter.default.publisher(for: AlembicTrayController.openSettingsNotification)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AlembicTrayController.openImportNotification)) { _ in
            showImportSheet = true
        }
        .sheet(isPresented: $showBootDetail) {
            AlembicBootDetailSheet(
                state: state,
                onClose: { showBootDetail = false }
            )
        }
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text("Alembic Settings")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button {
                        showSettings = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.escape)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                Divider().opacity(0.25)
                AlembicSettingsWindow(
                    settingsState: settingsState,
                    accountsState: accountsState
                )
            }
            .frame(minWidth: 720, idealWidth: 820, minHeight: 540, idealHeight: 640)
            .background(AlembicSpikeBackground().ignoresSafeArea())
        }
        .sheet(isPresented: $showImportSheet) {
            AlembicImportSheet(
                state: workspaceState,
                onClose: { showImportSheet = false },
                onChooseFolder: {
                    AlembicWorkspaceBridge.shared.presentFolderPicker { path in
                        if let chosen: String = path {
                            AlembicWorkspaceBridge.shared.scanDirectory(chosen) { _, _ in }
                        }
                    }
                },
                onScan: { path in
                    AlembicWorkspaceBridge.shared.scanDirectory(path) { _, _ in }
                },
                onImport: { rootPath, slugs in
                    AlembicWorkspaceBridge.shared.importDiscovered(rootPath: rootPath, selectedSlugs: slugs) { ok, _ in
                        if ok {
                            showImportSheet = false
                            onRepositoryRefresh()
                        }
                    }
                }
            )
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "drop.degreesign")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                Text("Alembic")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            statusChip
            Button {
                showImportSheet = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down.on.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Import existing local repositories from a folder")
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .keyboardShortcut(",", modifiers: [.command])
            Button {
                showBootDetail = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.borderless)
            .help("Diagnostics info")
            Button {
                showDiagnostics.toggle()
            } label: {
                Image(systemName: showDiagnostics ? "stethoscope.circle.fill" : "stethoscope")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(showDiagnostics ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(showDiagnostics ? "Hide diagnostics console" : "Show diagnostics console")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var statusTint: Color {
        if state.accountCount > 0 {
            return .green
        }
        if state.ready {
            return .orange
        }
        return .secondary
    }

    private var statusLabel: String {
        if state.accountCount > 0 {
            if let login: String = state.primaryAccountLogin, !login.isEmpty {
                return "@\(login)"
            }
            return "Connected"
        }
        if state.ready {
            return "Not connected"
        }
        return "Starting..."
    }

    private var contentArea: some View {
        AlembicRepositoryListView(
            state: repositoryState,
            workState: workState,
            settingsState: settingsState,
            accountsState: accountsState,
            onRefresh: onRepositoryRefresh,
            onRetry: onRepositoryRetry,
            onOpen: onRepositoryOpen
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AlembicBootDetailSheet: View {
    @ObservedObject var state: SpikeAppState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Runtime")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Heartbeat", value: "tick \(state.heartbeat)")
                infoRow(label: "Status", value: state.status)
                infoRow(label: "Process", value: state.pid.isEmpty ? "-" : "pid \(state.pid)")
                infoRow(label: "Accounts", value: "\(state.accountCount)")
                infoRow(label: "Hive entries", value: "\(state.hiveEntries)")
                if let login: String = state.primaryAccountLogin {
                    infoRow(label: "Primary", value: "@\(login)")
                }
                if !state.configPath.isEmpty {
                    infoRow(label: "Data path", value: state.configPath, monospace: true)
                }
            }

            if state.migrationAttempted || !state.migrationSearchedPaths.isEmpty {
                Divider()
                migrationDetails
            }

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
        .background(AlembicSpikeGlassPanel())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var migrationDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Legacy data migration")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if state.migrationAttempted {
                if let source: String = state.migrationSourcePath {
                    infoRow(label: "Source", value: source, monospace: true)
                }
                if !state.migrationCopiedFiles.isEmpty {
                    infoRow(
                        label: "Copied",
                        value: state.migrationCopiedFiles.joined(separator: ", "),
                        tint: .green
                    )
                }
                if !state.migrationSkippedFiles.isEmpty {
                    infoRow(
                        label: "Skipped",
                        value: state.migrationSkippedFiles.joined(separator: ", "),
                        tint: .secondary
                    )
                }
            } else {
                Text("Searched \(state.migrationSearchedPaths.count) legacy paths; no usable account data found.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if !state.migrationSearchedPaths.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Paths searched")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.85))
                    ForEach(state.migrationSearchedPaths, id: \.self) { path in
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    private func infoRow(label: String, value: String, monospace: Bool = false, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(monospace
                    ? .system(size: 11, design: .monospaced)
                    : .system(size: 12))
                .foregroundStyle(tint)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(monospace ? 1 : nil)
                .truncationMode(.middle)
        }
    }
}

struct AlembicSpikeGlassPanel: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.thickMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct AlembicSpikeBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return AlembicGlassBackdrop()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let backdrop: AlembicGlassBackdrop = nsView as? AlembicGlassBackdrop {
            backdrop.refresh()
        }
    }
}
