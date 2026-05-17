import AppKit
import SwiftUI

struct AlembicRepositoryDetailSheet: View {
    let repository: RepositoryItem
    @ObservedObject var workState: RepositoryWorkBridgeState
    @ObservedObject var settingsState: SettingsBridgeState
    @ObservedObject var accountsState: AccountsBridgeState
    let onClose: () -> Void

    @State private var detail: AlembicRepositoryActionsBridge.RepositoryDetail? = nil
    @State private var repoConfig: RepoConfigDto? = nil
    @State private var loadError: String = ""
    @State private var isLoading: Bool = true
    @State private var actionInFlight: String? = nil
    @State private var lastActionResult: String? = nil
    @State private var lastActionError: String? = nil

    private var workEntries: [RepositoryWorkEntry] {
        return workState.workForRepo(repository.fullName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.25)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading {
                        loadingPlaceholder
                    } else if !loadError.isEmpty {
                        errorBanner(loadError)
                    } else {
                        summaryCard
                        actionsCard
                        if !workEntries.isEmpty {
                            workCard
                        }
                        archiveMasterCard
                        overridesCard
                        pathsCard
                    }
                }
                .padding(24)
            }
        }
        .frame(
            minWidth: 620,
            idealWidth: 760,
            minHeight: 540,
            idealHeight: 700
        )
        .background(AlembicSpikeBackground().ignoresSafeArea())
        .onAppear { loadDetail() }
        .onChange(of: workState.lastUpdateMs) { _ in loadDetailQuiet() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(stateColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: stateSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(stateColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(repository.owner)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(repository.name)
                        .font(.system(size: 14, weight: .semibold))
                }
                HStack(spacing: 8) {
                    badge(text: stateLabel, color: stateColor)
                    if repository.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    if repository.isFork {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                    }
                    if let lang: String = repository.language {
                        Text(lang)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                AlembicRepositoryListBridge.shared.openInBrowser(repository.htmlUrl)
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Open on GitHub")
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape)
        }
        .padding(20)
    }

    private var summaryCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                if !repository.description.isEmpty {
                    Text(repository.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 16) {
                    infoChip("Default branch", value: repository.defaultBranch.isEmpty ? "main" : repository.defaultBranch, systemImage: "arrow.triangle.branch")
                    infoChip("Stars", value: "\(repository.starCount)", systemImage: "star")
                    infoChip("Forks", value: "\(repository.forkCount)", systemImage: "tuningfork")
                    if let detail: AlembicRepositoryActionsBridge.RepositoryDetail = detail, detail.daysUntilArchival > 0 {
                        infoChip("Auto-archive in", value: "\(detail.daysUntilArchival) days", systemImage: "hourglass")
                    }
                }
                if let detail: AlembicRepositoryActionsBridge.RepositoryDetail = detail,
                   let lastOpenMs: Int64 = detail.lastOpenMs {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Last opened \(formatRelative(lastOpenMs))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.system(size: 12, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    actionButton("Open", systemImage: "play.fill", isProminent: true) {
                        runAction("open") { AlembicRepositoryActionsBridge.shared.open(fullName: repository.fullName, completion: $0) }
                    }
                    actionButton("Reveal in Finder", systemImage: "folder") {
                        runAction("openInFinder") { AlembicRepositoryActionsBridge.shared.openInFinder(fullName: repository.fullName, completion: $0) }
                    }
                    actionButton("Pull", systemImage: "arrow.down.circle") {
                        runAction("pull") { AlembicRepositoryActionsBridge.shared.pull(fullName: repository.fullName, completion: $0) }
                    }
                    actionButton("Fork & Clone", systemImage: "tuningfork") {
                        runAction("fork") { AlembicRepositoryActionsBridge.shared.fork(fullName: repository.fullName, completion: $0) }
                    }
                    if currentState == "active" || currentState == "cloud" {
                        actionButton("Archive", systemImage: "archivebox") {
                            runAction("archive") { AlembicRepositoryActionsBridge.shared.archive(fullName: repository.fullName, completion: $0) }
                        }
                    }
                    if currentState == "archived" {
                        actionButton("Unarchive", systemImage: "archivebox.fill") {
                            runAction("unarchive") { AlembicRepositoryActionsBridge.shared.unarchive(fullName: repository.fullName, completion: $0) }
                        }
                        actionButton("Update Archive", systemImage: "arrow.clockwise") {
                            runAction("updateArchive") { AlembicRepositoryActionsBridge.shared.updateArchive(fullName: repository.fullName, completion: $0) }
                        }
                    }
                    if currentState == "cloud" {
                        actionButton("Clone", systemImage: "arrow.down.circle.fill") {
                            runAction("clone") { AlembicRepositoryActionsBridge.shared.clone(fullName: repository.fullName, completion: $0) }
                        }
                        actionButton("Archive from cloud", systemImage: "icloud.and.arrow.down") {
                            runAction("archiveFromCloud") { AlembicRepositoryActionsBridge.shared.archiveFromCloud(fullName: repository.fullName, completion: $0) }
                        }
                    }
                }

                Divider().opacity(0.2)
                HStack(spacing: 8) {
                    Button {
                        confirmDestructive(
                            title: "Delete local copy?",
                            message: "This removes the local working tree only. The GitHub repository is untouched.",
                            confirmTitle: "Delete locally"
                        ) {
                            runAction("delete") { AlembicRepositoryActionsBridge.shared.delete(fullName: repository.fullName, completion: $0) }
                        }
                    } label: {
                        Label("Delete local copy", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(actionInFlight != nil || currentState == "cloud")

                    if currentState == "archived" {
                        Button {
                            confirmDestructive(
                                title: "Delete archive?",
                                message: "This permanently removes the .tar.zst archive for this repository.",
                                confirmTitle: "Delete archive"
                            ) {
                                runAction("deleteArchive") { AlembicRepositoryActionsBridge.shared.deleteArchive(fullName: repository.fullName, completion: $0) }
                            }
                        } label: {
                            Label("Delete archive", systemImage: "trash.slash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                        .disabled(actionInFlight != nil)
                    }

                    Spacer()
                    if let action: String = actionInFlight {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                            Text("Running \(action)...")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let success: String = lastActionResult, !success.isEmpty {
                    statusBanner(success, tint: .green, systemImage: "checkmark.circle.fill")
                }
                if let error: String = lastActionError, !error.isEmpty {
                    statusBanner(error, tint: .red, systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
    }

    private var workCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("In progress")
                        .font(.system(size: 12, weight: .semibold))
                }
                ForEach(workEntries) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: kindSymbol(entry.kind))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(entry.message.isEmpty ? entry.kind : entry.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let progress: Double = entry.progress {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var archiveMasterCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Archive Master")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if let detail: AlembicRepositoryActionsBridge.RepositoryDetail = detail,
                       detail.archiveMasterFullName != nil {
                        Text("Enrolled")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green.opacity(0.12))
                            )
                    } else {
                        Text("Not enrolled")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }
                if let masterState: ArchiveMasterRepoStateDto = workState.archiveMasterState(for: repository.fullName) {
                    if let pulled: Int64 = masterState.lastPulledMs {
                        Text("Last pulled \(formatRelative(pulled))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let checked: Int64 = masterState.lastCheckedMs {
                        Text("Last checked \(formatRelative(checked))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let hash: String = masterState.lastCommitHash, !hash.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "number")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(hash.prefix(8)))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let err: String = masterState.lastErrorMessage, !err.isEmpty {
                        statusBanner(err, tint: .red, systemImage: "exclamationmark.triangle.fill")
                    }
                }

                HStack(spacing: 8) {
                    if detail?.archiveMasterFullName == nil {
                        Button {
                            runAction("enrollArchiveMaster") {
                                AlembicRepositoryActionsBridge.shared.enrollArchiveMaster(
                                    fullName: repository.fullName,
                                    completion: $0
                                )
                            }
                        } label: {
                            Label("Enroll", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button {
                            runAction("refreshArchiveMaster") {
                                AlembicRepositoryActionsBridge.shared.refreshArchiveMaster(
                                    fullName: repository.fullName,
                                    completion: $0
                                )
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button {
                            runAction("promoteArchiveMaster") {
                                AlembicRepositoryActionsBridge.shared.promoteArchiveMaster(
                                    fullName: repository.fullName,
                                    completion: $0
                                )
                            }
                        } label: {
                            Label("Promote", systemImage: "arrow.up.heart")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Promote archive master into the active workspace.")
                        Button {
                            confirmDestructive(
                                title: "Unenroll archive master?",
                                message: "This stops tracking remote refs for this repository. It does not delete archived data.",
                                confirmTitle: "Unenroll"
                            ) {
                                runAction("unenrollArchiveMaster") {
                                    AlembicRepositoryActionsBridge.shared.unenrollArchiveMaster(
                                        fullName: repository.fullName,
                                        completion: $0
                                    )
                                }
                            }
                        } label: {
                            Label("Unenroll", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }
                }
            }
        }
    }

    private var overridesCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Per-repository overrides")
                    .font(.system(size: 12, weight: .semibold))
                Text("Override the default editor, Git client, or account used when interacting with this repository.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                overrideRow(
                    title: "Editor",
                    description: "Falls back to the global default when not set.",
                    options: settingsState.supportedEditorTools.map { ($0.name, $0.displayName) },
                    selection: repoConfig?.editorTool,
                    onSelect: { selected in updateOverride(editorTool: selected, clearEditor: false) },
                    onClear: { updateOverride(editorTool: nil, clearEditor: true) }
                )

                overrideRow(
                    title: "Git client",
                    description: "Falls back to the global default when not set.",
                    options: settingsState.supportedGitTools.map { ($0.name, $0.displayName) },
                    selection: repoConfig?.gitTool,
                    onSelect: { selected in updateOverride(gitTool: selected, clearGit: false) },
                    onClear: { updateOverride(gitTool: nil, clearGit: true) }
                )

                overrideRow(
                    title: "Account",
                    description: "Use this account when cloning/pulling this repository.",
                    options: accountsState.accounts.map { ($0.id, accountLabel(for: $0)) },
                    selection: repoConfig?.accountId,
                    onSelect: { selected in updateOverride(accountId: selected, clearAccount: false) },
                    onClear: { updateOverride(accountId: nil, clearAccount: true) }
                )
            }
        }
    }

    private var pathsCard: some View {
        AlembicSettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paths")
                    .font(.system(size: 12, weight: .semibold))
                if let detail: AlembicRepositoryActionsBridge.RepositoryDetail = detail {
                    pathEntry(label: "Working", path: detail.repoPath)
                    pathEntry(label: "Archive", path: detail.archivePath)
                    pathEntry(label: "Archive master", path: detail.archiveMasterPath)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
            Text("Loading repository details...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func statusBanner(_ message: String, tint: Color, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    @ViewBuilder
    private func actionButton(_ title: String, systemImage: String, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        if isProminent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(actionInFlight != nil)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(actionInFlight != nil)
        }
    }

    @ViewBuilder
    private func overrideRow(
        title: String,
        description: String,
        options: [(String, String)],
        selection: String?,
        onSelect: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Use global default") { onClear() }
                    if !options.isEmpty {
                        Divider()
                        ForEach(options, id: \.0) { (id, label) in
                            Button(label) { onSelect(id) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(displayLabel(for: selection, in: options))
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .menuStyle(.borderlessButton)
                .frame(minWidth: 140)
            }
        }
    }

    private func displayLabel(for id: String?, in options: [(String, String)]) -> String {
        guard let id: String = id else { return "Default" }
        if let match: (String, String) = options.first(where: { $0.0 == id }) {
            return match.1
        }
        return id
    }

    @ViewBuilder
    private func pathEntry(label: String, path: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(path.isEmpty ? "—" : path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }

    private func infoChip(_ label: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func accountLabel(for account: AccountItem) -> String {
        if let login: String = account.login, !login.isEmpty {
            return "\(account.name) (@\(login))"
        }
        return account.name
    }

    private var stateColor: Color {
        switch currentState {
        case "active": return .green
        case "archived": return .blue
        default: return .secondary
        }
    }

    private var stateSymbol: String {
        switch currentState {
        case "active": return "checkmark.circle.fill"
        case "archived": return "archivebox.fill"
        default: return "cloud"
        }
    }

    private var stateLabel: String {
        switch currentState {
        case "active": return "Active"
        case "archived": return "Archived"
        default: return "Cloud"
        }
    }

    private var currentState: String {
        if let s: String = detail?.state { return s }
        if workState.isActive(repository.fullName) { return "active" }
        if workState.isArchived(repository.fullName) { return "archived" }
        return "cloud"
    }

    private func kindSymbol(_ kind: String) -> String {
        switch kind {
        case "clone": return "arrow.down.circle"
        case "pull": return "arrow.down"
        case "archive": return "archivebox"
        case "unarchive": return "archivebox.fill"
        case "fork": return "tuningfork"
        case "delete": return "trash"
        case "archiveMasterPull": return "archivebox.circle"
        default: return "circle.dashed"
        }
    }

    private func loadDetail() {
        isLoading = true
        loadError = ""
        AlembicRepositoryActionsBridge.shared.getDetail(fullName: repository.fullName) { result in
            isLoading = false
            if !result.ok {
                loadError = result.error ?? "Failed to load details."
                detail = nil
                return
            }
            detail = result
        }
        AlembicSettingsBridge.shared.getRepoConfig(fullName: repository.fullName) { result in
            if result.ok {
                repoConfig = result.config
            }
        }
    }

    private func loadDetailQuiet() {
        AlembicRepositoryActionsBridge.shared.getDetail(fullName: repository.fullName) { result in
            if result.ok {
                detail = result
            }
        }
    }

    private func runAction(
        _ name: String,
        invoke: @escaping (@escaping (AlembicRepositoryActionsBridge.ActionResult) -> Void) -> Void
    ) {
        actionInFlight = name
        lastActionError = nil
        lastActionResult = nil
        invoke { result in
            actionInFlight = nil
            if result.ok {
                lastActionResult = "\(name) succeeded"
                loadDetail()
            } else {
                lastActionError = result.error ?? "\(name) failed"
            }
        }
    }

    private func updateOverride(
        editorTool: String? = nil,
        gitTool: String? = nil,
        accountId: String? = nil,
        clearEditor: Bool = false,
        clearGit: Bool = false,
        clearAccount: Bool = false
    ) {
        AlembicSettingsBridge.shared.setRepoConfig(
            fullName: repository.fullName,
            editorTool: editorTool,
            gitTool: gitTool,
            openDirectory: nil,
            accountId: accountId,
            clearEditor: clearEditor,
            clearGit: clearGit,
            clearAccount: clearAccount
        ) { result in
            if result.ok {
                repoConfig = result.config
            } else {
                lastActionError = result.error ?? "Override update failed"
            }
        }
    }

    private func confirmDestructive(
        title: String,
        message: String,
        confirmTitle: String,
        action: @escaping () -> Void
    ) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        let response: NSApplication.ModalResponse = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
        }
    }

    private func formatRelative(_ ms: Int64) -> String {
        let date: Date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let formatter: RelativeDateTimeFormatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

