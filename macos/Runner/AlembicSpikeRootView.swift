import AppKit
import SwiftUI

struct AlembicSpikeRootView: View {
    let state: SpikeAppState
    let repositoryState: RepositoryListBridgeState
    let diagnosticsState: AlembicDiagnosticsState
    let workspaceState: WorkspaceBridgeState
    let workState: RepositoryWorkBridgeState
    let settingsState: SettingsBridgeState
    let accountsState: AccountsBridgeState
    let onRepositoryRefresh: () -> Void
    let onRepositoryRetry: () -> Void
    let onRepositoryOpen: (String) -> Void
    @State private var showDiagnostics: Bool = false
    @State private var showBootDetail: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var showSettings: Bool = false
    @ObservedObject private var legibility: AlembicGlassLegibilityController = AlembicGlassLegibilityController.shared

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 10) {
                    rootStack
                }
            } else {
                rootStack
            }
        }
        .environment(\.colorScheme, legibility.colorScheme)
        .onAppear {
            legibility.refresh()
        }
        .frame(
            minWidth: 920,
            idealWidth: 1080,
            minHeight: 600,
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

    private var rootStack: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            if showSettings {
                settingsScreen
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    contentArea
                    if showDiagnostics {
                        AlembicDiagnosticsConsole(state: diagnosticsState)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.top, 14)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(AlembicGlassTokens.appPadding)
                .transition(.opacity)
            }
        }
    }

    private var contentArea: some View {
        AlembicRepositoryListView(
            state: repositoryState,
            workState: workState,
            settingsState: settingsState,
            accountsState: accountsState,
            onRefresh: onRepositoryRefresh,
            onRetry: onRepositoryRetry,
            onOpen: onRepositoryOpen,
            onImport: { showImportSheet = true },
            onSettings: { showSettings = true },
            onRuntimeInfo: { showBootDetail = true },
            onDiagnostics: { showDiagnostics.toggle() },
            diagnosticsVisible: showDiagnostics
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var settingsScreen: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    showSettings = false
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Divider()
                .opacity(0.4)
            AlembicSettingsWindow(
                settingsState: settingsState,
                accountsState: accountsState
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(AlembicGlassTokens.appPadding)
        .onExitCommand {
            showSettings = false
        }
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
        .alembicGlassSurface(.sheet)
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

struct AlembicSpikeBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view: NSView = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
