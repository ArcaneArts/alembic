import AppKit
import SwiftUI

enum AlembicScreen: Equatable {
    case main
    case settings
    case runtime
    case importPage
    case diagnostics
}

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
    @State private var currentScreen: AlembicScreen = .main
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
            currentScreen = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: AlembicTrayController.openImportNotification)) { _ in
            currentScreen = .importPage
        }
    }

    private var rootStack: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            Group {
                switch currentScreen {
                case .main:
                    mainScreen
                case .settings:
                    settingsScreen
                case .runtime:
                    runtimeScreen
                case .importPage:
                    importScreen
                case .diagnostics:
                    diagnosticsScreen
                }
            }
            .transition(.opacity)
        }
    }

    private var mainScreen: some View {
        AlembicRepositoryListView(
            state: repositoryState,
            workState: workState,
            settingsState: settingsState,
            accountsState: accountsState,
            onRefresh: onRepositoryRefresh,
            onRetry: onRepositoryRetry,
            onOpen: onRepositoryOpen,
            onImport: { currentScreen = .importPage },
            onSettings: { currentScreen = .settings },
            onRuntimeInfo: { currentScreen = .runtime },
            onDiagnostics: { currentScreen = .diagnostics },
            diagnosticsVisible: currentScreen == .diagnostics
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AlembicGlassTokens.appPadding)
    }

    @ViewBuilder
    private func pageWrapper<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: AlembicGlassTokens.panelSpacing) {
            pageHeader(title: title, systemImage: systemImage)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(AlembicGlassTokens.appPadding)
        .onExitCommand {
            currentScreen = .main
        }
    }

    private func pageHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                currentScreen = .main
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: [])
            .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(minHeight: AlembicGlassTokens.commandHeight)
        .alembicGlassSurface(.toolbar)
    }

    private var settingsScreen: some View {
        pageWrapper(title: "Settings", systemImage: "gearshape") {
            AlembicSettingsWindow(
                settingsState: settingsState,
                accountsState: accountsState
            )
        }
    }

    private var runtimeScreen: some View {
        pageWrapper(title: "Runtime", systemImage: "info.circle.fill") {
            AlembicRuntimePage(state: state)
        }
    }

    private var importScreen: some View {
        pageWrapper(title: "Import Repositories", systemImage: "folder.fill.badge.plus") {
            AlembicImportSheet(
                state: workspaceState,
                onClose: { currentScreen = .main },
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
                            currentScreen = .main
                            onRepositoryRefresh()
                        }
                    }
                }
            )
        }
    }

    private var diagnosticsScreen: some View {
        pageWrapper(title: "Diagnostics", systemImage: "stethoscope") {
            AlembicDiagnosticsConsole(state: diagnosticsState)
        }
    }
}

struct AlembicRuntimePage: View {
    @ObservedObject var state: SpikeAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .alembicGlassSurface(.panel)

                if state.migrationAttempted || !state.migrationSearchedPaths.isEmpty {
                    migrationDetails
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .alembicGlassSurface(.panel)
                }
            }
            .padding(2)
        }
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
