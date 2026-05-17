import AppKit
import SwiftUI

struct AlembicGlassCardBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        return AlembicGlassBackdrop(
            frame: NSRect(x: 0, y: 0, width: 1, height: 1),
            cornerRadius: cornerRadius
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let backdrop: AlembicGlassBackdrop = nsView as? AlembicGlassBackdrop {
            backdrop.setCornerRadius(cornerRadius)
            backdrop.refresh()
        }
    }
}

struct AlembicRepositoryListView: View {
    @ObservedObject var state: RepositoryListBridgeState
    @ObservedObject var workState: RepositoryWorkBridgeState
    @ObservedObject var settingsState: SettingsBridgeState
    @ObservedObject var accountsState: AccountsBridgeState
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onOpen: (String) -> Void

    @State private var isSignInSheetVisible: Bool = false
    @State private var searchQuery: String = ""
    @State private var ownerFilter: String = ""
    @State private var stateFilter: String = "all"
    @State private var detailRepository: RepositoryItem? = nil

    private var filteredRepositories: [RepositoryItem] {
        let q: String = searchQuery.lowercased()
        return state.repositories.filter { item in
            let matchesQuery: Bool = q.isEmpty
                || item.fullName.lowercased().contains(q)
                || item.description.lowercased().contains(q)
            let matchesOwner: Bool = ownerFilter.isEmpty || item.owner == ownerFilter
            let matchesState: Bool = stateMatches(item)
            return matchesQuery && matchesOwner && matchesState
        }
    }

    private func stateMatches(_ item: RepositoryItem) -> Bool {
        switch stateFilter {
        case "active": return workState.isActive(item.fullName)
        case "archived": return workState.isArchived(item.fullName)
        case "cloud":
            return !workState.isActive(item.fullName) && !workState.isArchived(item.fullName)
        case "syncing": return workState.isSyncing(item.fullName)
        default: return true
        }
    }

    private var availableOwners: [String] {
        var owners: Set<String> = []
        for repo in state.repositories {
            owners.insert(repo.owner)
        }
        return Array(owners).sorted()
    }

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isSignInSheetVisible) {
            AlembicSignInSheet(
                onSubmit: { token, name, completion in
                    AlembicRepositoryListBridge.shared.signInWithToken(
                        token: token,
                        name: name
                    ) { result in
                        completion(result)
                    }
                },
                onClose: {
                    isSignInSheetVisible = false
                }
            )
        }
        .sheet(item: $detailRepository) { repo in
            AlembicRepositoryDetailSheet(
                repository: repo,
                workState: workState,
                settingsState: settingsState,
                accountsState: accountsState,
                onClose: { detailRepository = nil }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.status {
        case "loading":
            loadingState
        case "noAccount":
            welcomeState
        case "error", "timeout":
            errorState
        case "empty":
            emptyState
        case "ready":
            readyState
        default:
            initialState
        }
    }

    private var welcomeState: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 18) {
                Image(systemName: "drop.degreesign")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor.opacity(0.95), .accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                VStack(spacing: 6) {
                    Text("Welcome to Alembic")
                        .font(.system(size: 22, weight: .semibold))
                    Text("A native macOS GitHub workspace manager.\nConnect your GitHub account to load your repositories.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) {
                    Button {
                        isSignInSheetVisible = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Connect with Personal Access Token")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    Button {
                        onOpen("https://github.com/settings/tokens/new?scopes=repo,read:org&description=Alembic")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("Generate new token on GitHub")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .center, spacing: 6) {
                    Text("REQUIRED SCOPES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.secondary.opacity(0.75))
                    HStack(spacing: 6) {
                        scopeBadge("repo")
                        scopeBadge("read:org")
                    }
                }
                .padding(.top, 4)
            }
            .padding(40)
            .frame(maxWidth: 520)
            .background(AlembicSpikeGlassPanel())
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(40)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                VStack(spacing: 4) {
                    Text(loadingTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Text(loadingSubtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if state.fetchedCount > 0 {
                    Text("\(state.fetchedCount) repositories fetched")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(36)
            .frame(maxWidth: 420)
            .background(AlembicSpikeGlassPanel())
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingTitle: String {
        switch state.phase {
        case "preparing": return "Preparing"
        case "resolving_account": return "Resolving account"
        case "connecting": return "Connecting to GitHub"
        case "requesting_page":
            return state.pageNumber > 0
                ? "Fetching page \(state.pageNumber)"
                : "Fetching repositories"
        case "page_complete": return "Loading more"
        case "rate_limited": return "Rate limited"
        default: return "Loading repositories"
        }
    }

    private var loadingSubtitle: String {
        if !state.endpoint.isEmpty {
            return state.endpoint
        }
        if state.attempt > 1 {
            return "attempt \(state.attempt)"
        }
        return "please wait"
    }

    private var errorState: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                VStack(spacing: 4) {
                    Text("Could not load repositories")
                        .font(.system(size: 14, weight: .semibold))
                    Text(state.errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
                if !state.errorCode.isEmpty {
                    Text(state.errorCode)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
                HStack(spacing: 8) {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .keyboardShortcut(.defaultAction)
                    Button("Sign in again") {
                        isSignInSheetVisible = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
            .padding(32)
            .frame(maxWidth: 480)
            .background(AlembicSpikeGlassPanel())
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No repositories")
                    .font(.system(size: 14, weight: .semibold))
                Text("@\(state.accountLogin) has no repositories.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Refresh", action: onRefresh)
                    .buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: 360)
            .background(AlembicSpikeGlassPanel())
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var initialState: some View {
        VStack {
            Spacer(minLength: 0)
            ProgressView("Starting...")
                .controlSize(.regular)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readyState: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.25)
            if filteredRepositories.isEmpty {
                noResultsRow
            } else {
                repositoryList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search repositories", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .frame(maxWidth: 320)

            Menu {
                Button("All") { stateFilter = "all" }
                Divider()
                Button("Active (\(workState.activeRepositories.count))") { stateFilter = "active" }
                Button("Archived (\(workState.archivedRepositories.count))") { stateFilter = "archived" }
                Button("Cloud only") { stateFilter = "cloud" }
                Button("Syncing (\(workState.syncingRepositories.count))") { stateFilter = "syncing" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: stateFilterIcon)
                        .font(.system(size: 11))
                    Text(stateFilterLabel)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 130)

            if availableOwners.count > 1 {
                Menu {
                    Button("All organizations") { ownerFilter = "" }
                    Divider()
                    ForEach(availableOwners, id: \.self) { owner in
                        Button(owner) { ownerFilter = owner }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 11))
                        Text(ownerFilter.isEmpty ? "All orgs" : ownerFilter)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 130)
            }

            Spacer()

            Text(repositoryCountLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            .disabled(state.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var stateFilterIcon: String {
        switch stateFilter {
        case "active": return "checkmark.circle"
        case "archived": return "archivebox"
        case "cloud": return "cloud"
        case "syncing": return "arrow.triangle.2.circlepath"
        default: return "circle.grid.2x2"
        }
    }

    private var stateFilterLabel: String {
        switch stateFilter {
        case "active": return "Active"
        case "archived": return "Archived"
        case "cloud": return "Cloud"
        case "syncing": return "Syncing"
        default: return "All states"
        }
    }

    private var repositoryCountLabel: String {
        let total: Int = state.repositories.count
        let shown: Int = filteredRepositories.count
        if total == shown {
            return "\(total) repos"
        }
        return "\(shown) of \(total)"
    }

    private var repositoryList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(filteredRepositories) { item in
                    AlembicRepositoryRow(
                        item: item,
                        workState: workState,
                        onOpenBrowser: { onOpen(item.htmlUrl) },
                        onShowDetail: { detailRepository = item }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var noResultsRow: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text("No repositories match")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                if !searchQuery.isEmpty || !ownerFilter.isEmpty || stateFilter != "all" {
                    Button("Clear filters") {
                        searchQuery = ""
                        ownerFilter = ""
                        stateFilter = "all"
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scopeBadge(_ scope: String) -> some View {
        Text(scope)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.30), lineWidth: 0.5)
            )
    }
}

struct AlembicRepositoryRow: View {
    let item: RepositoryItem
    @ObservedObject var workState: RepositoryWorkBridgeState
    let onOpenBrowser: () -> Void
    let onShowDetail: () -> Void
    @State private var isHovering: Bool = false
    @State private var actionInFlight: String? = nil

    private var isActive: Bool { workState.isActive(item.fullName) }
    private var isArchived: Bool { workState.isArchived(item.fullName) }
    private var isSyncing: Bool { workState.isSyncing(item.fullName) }
    private var workEntries: [RepositoryWorkEntry] { workState.workForRepo(item.fullName) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            stateColumn
            languageIndicator
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.owner)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    if item.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                    if item.isFork {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 9))
                            .foregroundStyle(.purple)
                    }
                    if item.isArchived {
                        Text("github archived")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.secondary.opacity(0.75))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                }
                if let work: RepositoryWorkEntry = workEntries.first {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.45)
                            .frame(width: 10, height: 10)
                        Text(work.message.isEmpty ? work.kind : work.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            HStack(spacing: 14) {
                if item.starCount > 0 {
                    metric(icon: "star", value: item.starCount)
                }
                if item.forkCount > 0 {
                    metric(icon: "arrow.triangle.branch", value: item.forkCount)
                }
            }
            .opacity(isHovering ? 1.0 : 0.6)
            HStack(spacing: 4) {
                primaryActionButton
                Button {
                    onShowDetail()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isHovering ? Color.accentColor : .secondary)
                .help("Show details")
                Button {
                    onOpenBrowser()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isHovering ? Color.accentColor : .secondary)
                .help("Open on GitHub")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onShowDetail()
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var stateColumn: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(0.16))
                .frame(width: 22, height: 22)
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.45)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: stateSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(stateColor)
            }
        }
        .help(stateTooltip)
    }

    private var stateColor: Color {
        if isSyncing { return .accentColor }
        if isActive { return .green }
        if isArchived { return .blue }
        return .secondary
    }

    private var stateSymbol: String {
        if isActive { return "checkmark" }
        if isArchived { return "archivebox.fill" }
        return "cloud"
    }

    private var stateTooltip: String {
        if isSyncing { return "Syncing" }
        if isActive { return "Active locally" }
        if isArchived { return "Archived" }
        return "Cloud only"
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if let action: String = actionInFlight {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.45)
                    .frame(width: 10, height: 10)
                Text(action)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else if isActive {
            Button {
                runAction("open") { AlembicRepositoryActionsBridge.shared.open(fullName: item.fullName, completion: $0) }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isHovering ? Color.accentColor : .secondary)
            .help("Open in editor")
        } else if isArchived {
            Button {
                runAction("unarchive") { AlembicRepositoryActionsBridge.shared.unarchive(fullName: item.fullName, completion: $0) }
            } label: {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isHovering ? Color.accentColor : .secondary)
            .help("Unarchive")
        } else {
            Button {
                runAction("clone") { AlembicRepositoryActionsBridge.shared.clone(fullName: item.fullName, completion: $0) }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isHovering ? Color.accentColor : .secondary)
            .help("Clone")
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Show details") { onShowDetail() }
        Button("Open on GitHub") { onOpenBrowser() }
        Divider()
        if isActive {
            Button("Open") { runAction("open") { AlembicRepositoryActionsBridge.shared.open(fullName: item.fullName, completion: $0) } }
            Button("Reveal in Finder") { runAction("openInFinder") { AlembicRepositoryActionsBridge.shared.openInFinder(fullName: item.fullName, completion: $0) } }
            Button("Pull") { runAction("pull") { AlembicRepositoryActionsBridge.shared.pull(fullName: item.fullName, completion: $0) } }
            Divider()
            Button("Archive") { runAction("archive") { AlembicRepositoryActionsBridge.shared.archive(fullName: item.fullName, completion: $0) } }
        } else if isArchived {
            Button("Unarchive") { runAction("unarchive") { AlembicRepositoryActionsBridge.shared.unarchive(fullName: item.fullName, completion: $0) } }
            Button("Update Archive") { runAction("updateArchive") { AlembicRepositoryActionsBridge.shared.updateArchive(fullName: item.fullName, completion: $0) } }
            Button("Reveal in Finder") { runAction("openInFinder") { AlembicRepositoryActionsBridge.shared.openInFinder(fullName: item.fullName, completion: $0) } }
        } else {
            Button("Clone") { runAction("clone") { AlembicRepositoryActionsBridge.shared.clone(fullName: item.fullName, completion: $0) } }
            Button("Archive from cloud") { runAction("archiveFromCloud") { AlembicRepositoryActionsBridge.shared.archiveFromCloud(fullName: item.fullName, completion: $0) } }
        }
        Divider()
        Button("Fork & clone") { runAction("fork") { AlembicRepositoryActionsBridge.shared.fork(fullName: item.fullName, completion: $0) } }
        Menu("Archive Master") {
            Button("Enroll") { runAction("enrollArchiveMaster") { AlembicRepositoryActionsBridge.shared.enrollArchiveMaster(fullName: item.fullName, completion: $0) } }
            Button("Refresh") { runAction("refreshArchiveMaster") { AlembicRepositoryActionsBridge.shared.refreshArchiveMaster(fullName: item.fullName, completion: $0) } }
            Button("Promote") { runAction("promoteArchiveMaster") { AlembicRepositoryActionsBridge.shared.promoteArchiveMaster(fullName: item.fullName, completion: $0) } }
            Divider()
            Button("Unenroll") { runAction("unenrollArchiveMaster") { AlembicRepositoryActionsBridge.shared.unenrollArchiveMaster(fullName: item.fullName, completion: $0) } }
        }
    }

    private func runAction(
        _ name: String,
        invoke: @escaping (@escaping (AlembicRepositoryActionsBridge.ActionResult) -> Void) -> Void
    ) {
        actionInFlight = name
        invoke { _ in
            actionInFlight = nil
        }
    }

    private var languageIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(languageColor(item.language))
                .frame(width: 8, height: 8)
            if let language: String = item.language {
                Text(language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
            } else {
                Text(" ")
                    .font(.system(size: 10))
                    .frame(width: 60, alignment: .leading)
            }
        }
    }

    private func metric(icon: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(formatMetric(value))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }

    private func formatMetric(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }

    private func languageColor(_ language: String?) -> Color {
        guard let lang: String = language else {
            return Color.secondary.opacity(0.4)
        }
        switch lang.lowercased() {
        case "swift": return .orange
        case "dart": return Color(red: 0.04, green: 0.65, blue: 0.84)
        case "rust": return Color(red: 0.86, green: 0.45, blue: 0.16)
        case "javascript", "typescript": return .yellow
        case "python": return Color(red: 0.30, green: 0.55, blue: 0.80)
        case "go": return Color(red: 0.30, green: 0.72, blue: 0.86)
        case "ruby": return Color(red: 0.78, green: 0.20, blue: 0.20)
        case "kotlin": return .purple
        case "java": return Color(red: 0.70, green: 0.32, blue: 0.16)
        case "c", "c++": return .blue
        case "html", "css": return Color(red: 0.90, green: 0.36, blue: 0.20)
        case "shell", "bash": return .green
        default: return .accentColor
        }
    }
}
