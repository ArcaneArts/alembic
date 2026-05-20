import AppKit
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case workspace
    case tools
    case archiveMaster
    case accounts
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .workspace: return "Workspace"
        case .tools: return "Tools"
        case .archiveMaster: return "Archive Master"
        case .accounts: return "Accounts"
        case .advanced: return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .workspace: return "folder"
        case .tools: return "wrench.and.screwdriver"
        case .archiveMaster: return "archivebox"
        case .accounts: return "person.crop.circle"
        case .advanced: return "ellipsis.circle"
        }
    }
}

struct AlembicSettingsWindow: View {
    @ObservedObject var settingsState: SettingsBridgeState
    @ObservedObject var accountsState: AccountsBridgeState
    @State private var selection: SettingsPane = .general

    var body: some View {
        HStack(spacing: 14) {
            sidebar
                .frame(width: 200)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .alembicGlassSurface(
                    .panel,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                )
        }
        .frame(
            minWidth: 720,
            idealWidth: 820,
            minHeight: 460,
            idealHeight: 520
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SettingsPane.allCases) { pane in
                Button {
                    selection = pane
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(selection == pane ? Color.accentColor : Color.secondary)
                            .frame(width: 18)
                        Text(pane.title)
                            .font(.system(size: 13, weight: selection == pane ? .semibold : .regular))
                            .foregroundStyle(selection == pane ? Color.primary : Color.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if selection == pane {
                            AlembicGlassSurface(
                                style: .control,
                                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                            ) {
                                Color.clear
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alembicGlassSurface(
            .sidebar,
            padding: EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            AlembicSettingsGeneralPane(state: settingsState)
        case .workspace:
            AlembicSettingsWorkspacePane(state: settingsState)
        case .tools:
            AlembicSettingsToolsPane(state: settingsState)
        case .archiveMaster:
            AlembicSettingsArchiveMasterPane(state: settingsState)
        case .accounts:
            AlembicSettingsAccountsPane(state: accountsState)
        case .advanced:
            AlembicSettingsAdvancedPane(settingsState: settingsState)
        }
    }
}

private struct AlembicSettingsGeneralPane: View {
    @ObservedObject var state: SettingsBridgeState
    @ObservedObject private var legibility: AlembicGlassLegibilityController = AlembicGlassLegibilityController.shared
    @State private var autolaunch: Bool = true
    @State private var initialized: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(title: "General", description: "App-wide preferences and startup behavior.")

                AlembicSettingsCard {
                    settingRow(
                        title: "Appearance",
                        description: "Choose how Alembic looks. System follows your macOS theme."
                    ) {
                        Picker(
                            "",
                            selection: Binding<AlembicThemePreference>(
                                get: { legibility.preference },
                                set: { next in legibility.setPreference(next) }
                            )
                        ) {
                            ForEach(AlembicThemePreference.allCases, id: \.self) { pref in
                                Text(pref.displayName).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }

                AlembicSettingsCard {
                    settingRow(
                        title: "Launch at startup",
                        description: "Open Alembic automatically when you sign in."
                    ) {
                        Toggle("", isOn: $autolaunch)
                            .labelsHidden()
                            .onChange(of: autolaunch) { newValue in
                                AlembicSettingsBridge.shared.setGeneral(autolaunch: newValue) { _ in }
                            }
                    }
                }

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data location")
                            .font(.system(size: 12, weight: .semibold))
                        Text(state.configPath.isEmpty ? "—" : state.configPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        HStack(spacing: 8) {
                            Button {
                                AlembicSettingsBridge.shared.revealDataFolder { _ in }
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onAppear {
            if !initialized {
                autolaunch = state.autolaunch
                initialized = true
            }
        }
        .onChange(of: state.autolaunch) { newValue in
            if newValue != autolaunch {
                autolaunch = newValue
            }
        }
    }
}

private struct AlembicSettingsWorkspacePane: View {
    @ObservedObject var state: SettingsBridgeState
    @State private var workspaceDirectory: String = ""
    @State private var archiveDirectory: String = ""
    @State private var archiveMasterDirectory: String = ""
    @State private var archiveEnabled: Bool = true
    @State private var daysToArchive: String = ""
    @State private var initialized: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(title: "Workspace", description: "Where Alembic stores active repositories, archives, and archive masters.")

                AlembicSettingsCard {
                    pathRow(
                        title: "Active workspace",
                        description: "Cloned repositories live here.",
                        path: $workspaceDirectory,
                        defaultPath: state.defaultWorkspaceDirectory,
                        onChoose: { chooseDirectory(into: $workspaceDirectory) },
                        onCommit: { commit() }
                    )
                }

                AlembicSettingsCard {
                    settingRow(
                        title: "Archive repositories",
                        description: archiveEnabled
                            ? "Idle repositories can be archived automatically."
                            : "Archive actions and automatic cleanup are disabled."
                    ) {
                        Toggle("", isOn: $archiveEnabled)
                            .labelsHidden()
                            .onChange(of: archiveEnabled) { _ in commit() }
                    }
                    if archiveEnabled {
                        Divider().opacity(0.2)
                        pathRow(
                            title: "Archive directory",
                            description: "Repositories that have been archived are stored here.",
                            path: $archiveDirectory,
                            defaultPath: state.defaultArchiveDirectory,
                            onChoose: { chooseDirectory(into: $archiveDirectory) },
                            onCommit: { commit() }
                        )
                        Divider().opacity(0.2)
                        settingRow(
                            title: "Archive after",
                            description: "Idle repositories are auto-archived after this many days."
                        ) {
                            HStack(spacing: 6) {
                                TextField("days", text: $daysToArchive)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                    .onSubmit { commit() }
                                Text("days")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if archiveEnabled {
                    AlembicSettingsCard {
                        pathRow(
                            title: "Archive Master directory",
                            description: "Mirror clones used by Archive Master.",
                            path: $archiveMasterDirectory,
                            defaultPath: state.defaultArchiveMasterDirectory,
                            onChoose: { chooseDirectory(into: $archiveMasterDirectory) },
                            onCommit: { commit() }
                        )
                    }
                }

                HStack {
                    Spacer()
                    Button("Save Workspace") { commit() }
                        .buttonStyle(.borderedProminent)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onAppear { syncFromState() }
        .onChange(of: state.lastUpdateMs) { _ in syncFromState() }
    }

    private func syncFromState() {
        if !initialized {
            initialized = true
            workspaceDirectory = state.workspaceDirectory
            archiveDirectory = state.archiveDirectory
            archiveMasterDirectory = state.archiveMasterDirectory
            archiveEnabled = state.archiveEnabled
            daysToArchive = "\(state.daysToArchive)"
            return
        }
        if workspaceDirectory != state.workspaceDirectory { workspaceDirectory = state.workspaceDirectory }
        if archiveDirectory != state.archiveDirectory { archiveDirectory = state.archiveDirectory }
        if archiveMasterDirectory != state.archiveMasterDirectory { archiveMasterDirectory = state.archiveMasterDirectory }
        if archiveEnabled != state.archiveEnabled { archiveEnabled = state.archiveEnabled }
        let stateDays: String = "\(state.daysToArchive)"
        if daysToArchive != stateDays { daysToArchive = stateDays }
    }

    private func commit() {
        let days: Int? = Int(daysToArchive)
        AlembicSettingsBridge.shared.setWorkspace(
            workspaceDirectory: workspaceDirectory,
            archiveDirectory: archiveDirectory,
            archiveMasterDirectory: archiveMasterDirectory,
            archiveEnabled: archiveEnabled,
            daysToArchive: days
        ) { _ in }
    }

    private func chooseDirectory(into binding: Binding<String>) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if !binding.wrappedValue.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: binding.wrappedValue)
        }
        if panel.runModal() == .OK, let url: URL = panel.url {
            binding.wrappedValue = url.path
        }
    }
}

private struct AlembicSettingsToolsPane: View {
    @ObservedObject var state: SettingsBridgeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(title: "Tools", description: "Default editor and Git client used when opening repositories.")

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Editor")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("Editor", selection: editorBinding) {
                            ForEach(state.supportedEditorTools) { tool in
                                Text(tool.displayName).tag(tool.name as String?)
                            }
                            if !state.supportedEditorTools.contains(where: { $0.name == state.editorTool }) && state.editorTool != nil {
                                Text("Unsupported").tag(state.editorTool)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        if let help: String = selectedEditorHelp, !help.isEmpty {
                            Text(help)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Git client")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("Git Tool", selection: gitBinding) {
                            ForEach(state.supportedGitTools) { tool in
                                Text(tool.displayName).tag(tool.name as String?)
                            }
                            if !state.supportedGitTools.contains(where: { $0.name == state.gitTool }) && state.gitTool != nil {
                                Text("Unsupported").tag(state.gitTool)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private var editorBinding: Binding<String?> {
        Binding(
            get: { state.editorTool },
            set: { newValue in
                if let v: String = newValue {
                    AlembicSettingsBridge.shared.setTools(editorTool: v, gitTool: nil) { _ in }
                }
            }
        )
    }

    private var gitBinding: Binding<String?> {
        Binding(
            get: { state.gitTool },
            set: { newValue in
                if let v: String = newValue {
                    AlembicSettingsBridge.shared.setTools(editorTool: nil, gitTool: v) { _ in }
                }
            }
        )
    }

    private var selectedEditorHelp: String? {
        return state.supportedEditorTools.first(where: { $0.name == state.editorTool })?.help
    }
}

private struct AlembicSettingsArchiveMasterPane: View {
    @ObservedObject var state: SettingsBridgeState
    @State private var minutes: String = ""
    @State private var initialized: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(
                    title: "Archive Master",
                    description: "Mirror clones that keep a read-only fetch of remote refs for archived repositories."
                )

                if state.archiveEnabled {
                    AlembicSettingsCard {
                        settingRow(
                            title: "Refresh interval",
                            description: "How often archive master mirrors are refreshed against GitHub."
                        ) {
                            HStack(spacing: 6) {
                                TextField("minutes", text: $minutes)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                    .onSubmit { commit() }
                                Text("minutes")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Save Archive Master") { commit() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    AlembicSettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Archive is off")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Archive Master mirrors are paused while repository archiving is disabled.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onAppear { syncFromState() }
        .onChange(of: state.lastUpdateMs) { _ in syncFromState() }
    }

    private func syncFromState() {
        if !initialized {
            initialized = true
            minutes = "\(state.archiveMasterIntervalMinutes)"
            return
        }
        let s: String = "\(state.archiveMasterIntervalMinutes)"
        if minutes != s { minutes = s }
    }

    private func commit() {
        guard let v: Int = Int(minutes), v > 0 else { return }
        AlembicSettingsBridge.shared.setArchiveMaster(intervalMinutes: v) { _ in }
    }
}

private struct AlembicSettingsAccountsPane: View {
    @ObservedObject var state: AccountsBridgeState
    @State private var showAddSheet: Bool = false
    @State private var renamingId: String? = nil
    @State private var renamingValue: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(
                    title: "Accounts",
                    description: "GitHub accounts available for cloning, archiving, and pushing. The primary account is used when no override is set."
                )

                if state.accounts.isEmpty {
                    AlembicSettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No accounts yet")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Connect a GitHub Personal Access Token to load repositories.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Button("Connect with token") { showAddSheet = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    AlembicSettingsCard {
                        VStack(spacing: 0) {
                            ForEach(state.accounts) { account in
                                AccountRow(
                                    account: account,
                                    isPrimary: account.id == state.primaryAccountId,
                                    isRenaming: renamingId == account.id,
                                    renamingValue: $renamingValue,
                                    onMakePrimary: { setPrimary(account) },
                                    onBeginRename: { beginRename(account) },
                                    onCommitRename: { commitRename(account) },
                                    onCancelRename: { renamingId = nil },
                                    onRemove: { remove(account) }
                                )
                                if account.id != state.accounts.last?.id {
                                    Divider().opacity(0.2)
                                }
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Add account", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .sheet(isPresented: $showAddSheet) {
            AlembicSignInSheet(
                onSubmit: { token, name, completion in
                    AlembicAccountsBridge.shared.addAccount(token: token, name: name) { result in
                        completion(.init(
                            ok: result.ok,
                            login: result.login,
                            accountId: result.accountId,
                            errorMessage: result.error
                        ))
                        if result.ok {
                            DispatchQueue.main.async {
                                showAddSheet = false
                            }
                        }
                    }
                },
                onClose: { showAddSheet = false }
            )
        }
    }

    private func setPrimary(_ account: AccountItem) {
        AlembicAccountsBridge.shared.setPrimary(accountId: account.id) { _ in }
    }

    private func beginRename(_ account: AccountItem) {
        renamingId = account.id
        renamingValue = account.name
    }

    private func commitRename(_ account: AccountItem) {
        let name: String = renamingValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { renamingId = nil; return }
        AlembicAccountsBridge.shared.renameAccount(accountId: account.id, name: name) { _ in
            DispatchQueue.main.async {
                renamingId = nil
            }
        }
    }

    private func remove(_ account: AccountItem) {
        let alert: NSAlert = NSAlert()
        alert.messageText = "Remove account \(account.name)?"
        alert.informativeText = "Alembic will no longer use this account. Repositories pinned to it will fall back to the primary account."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        let response: NSApplication.ModalResponse = alert.runModal()
        if response == .alertFirstButtonReturn {
            AlembicAccountsBridge.shared.removeAccount(accountId: account.id) { _ in }
        }
    }
}

private struct AccountRow: View {
    let account: AccountItem
    let isPrimary: Bool
    let isRenaming: Bool
    @Binding var renamingValue: String
    let onMakePrimary: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isPrimary ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                    .frame(width: 30, height: 30)
                Image(systemName: isPrimary ? "checkmark.seal.fill" : "person.crop.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.accentColor : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Name", text: $renamingValue, onCommit: onCommitRename)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                } else {
                    Text(account.name)
                        .font(.system(size: 12, weight: .semibold))
                }
                HStack(spacing: 6) {
                    if let login: String = account.login, !login.isEmpty {
                        Text("@\(login)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Text(account.tokenDescription)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(.secondary.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }
            Spacer()
            HStack(spacing: 6) {
                if isRenaming {
                    Button("Save") { onCommitRename() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Cancel") { onCancelRename() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    if !isPrimary {
                        Button("Make Primary") { onMakePrimary() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Menu {
                        Button("Rename") { onBeginRename() }
                        Divider()
                        Button("Remove", role: .destructive) { onRemove() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 13))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 22)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct AlembicSettingsAdvancedPane: View {
    @ObservedObject var settingsState: SettingsBridgeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader(title: "Advanced", description: "Diagnostic tools and recovery options.")

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Diagnostics console")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Use the stethoscope button in the main window to toggle the live diagnostic stream.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reveal data folder")
                            .font(.system(size: 12, weight: .semibold))
                        Text(settingsState.configPath.isEmpty ? "—" : settingsState.configPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Button("Reveal in Finder") {
                            AlembicSettingsBridge.shared.revealDataFolder { _ in }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                AlembicSettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tray status item")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Recreate the menu bar tray icon if it has gone missing.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Button("Recreate Tray Icon") {
                            AlembicTrayController.shared.recreate(activate: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }
}

struct AlembicSettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.card.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.055 : 0.19))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.card.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.34), lineWidth: AlembicGlassTokens.hairline)
            )
    }
}

@ViewBuilder
private func paneHeader(title: String, description: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
        Text(description)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

@ViewBuilder
private func settingRow<TrailingContent: View>(
    title: String,
    description: String?,
    @ViewBuilder trailing: () -> TrailingContent
) -> some View {
    HStack(alignment: .center, spacing: 14) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            if let description: String = description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        Spacer()
        trailing()
    }
}

@ViewBuilder
private func pathRow(
    title: String,
    description: String,
    path: Binding<String>,
    defaultPath: String,
    onChoose: @escaping () -> Void,
    onCommit: @escaping () -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
            TextField("Path", text: path, onCommit: onCommit)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            Button {
                onChoose()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Choose folder")
        }
        if !defaultPath.isEmpty {
            Text("Default: \(defaultPath)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
