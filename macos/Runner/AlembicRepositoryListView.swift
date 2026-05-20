import AppKit
import SwiftUI

struct AlembicRepositoryListView: View {
    @ObservedObject var state: RepositoryListBridgeState
    @ObservedObject var workState: RepositoryWorkBridgeState
    @ObservedObject var settingsState: SettingsBridgeState
    @ObservedObject var accountsState: AccountsBridgeState
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onOpen: (String) -> Void
    let onImport: () -> Void
    let onSettings: () -> Void
    let onRuntimeInfo: () -> Void
    let onDiagnostics: () -> Void
    let diagnosticsVisible: Bool

    @State private var isSignInSheetVisible: Bool = false
    @State private var searchQuery: String = ""
    @State private var ownerFilter: String = ""
    @State private var stateFilter: String = "all"
    @State private var sortMode: String = "attention"
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
        }.sorted(by: compareRepositories)
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

    private func compareRepositories(_ lhs: RepositoryItem, _ rhs: RepositoryItem) -> Bool {
        switch sortMode {
        case "name":
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        case "owner":
            let ownerOrder: ComparisonResult = lhs.owner.localizedCaseInsensitiveCompare(rhs.owner)
            if ownerOrder != .orderedSame {
                return ownerOrder == .orderedAscending
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case "updated":
            if lhs.updatedAtMillis != rhs.updatedAtMillis {
                return lhs.updatedAtMillis > rhs.updatedAtMillis
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        case "archiveSoon":
            if !settingsState.archiveEnabled {
                return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
            let lhsActive: Bool = workState.isActive(lhs.fullName)
            let rhsActive: Bool = workState.isActive(rhs.fullName)
            if lhsActive != rhsActive {
                return lhsActive
            }
            let lhsDays: Int = daysUntilArchive(for: lhs)
            let rhsDays: Int = daysUntilArchive(for: rhs)
            if lhsActive && lhsDays != rhsDays {
                return lhsDays < rhsDays
            }
            let lhsRank: Int = stateRank(lhs)
            let rhsRank: Int = stateRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        case "state":
            let lhsRank: Int = stateRank(lhs)
            let rhsRank: Int = stateRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        default:
            let lhsRank: Int = attentionRank(lhs)
            let rhsRank: Int = attentionRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if workState.isActive(lhs.fullName) && workState.isActive(rhs.fullName) {
                let lhsDays: Int = daysUntilArchive(for: lhs)
                let rhsDays: Int = daysUntilArchive(for: rhs)
                if lhsDays != rhsDays {
                    return lhsDays < rhsDays
                }
            }
            if lhs.updatedAtMillis != rhs.updatedAtMillis {
                return lhs.updatedAtMillis > rhs.updatedAtMillis
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    private func attentionRank(_ item: RepositoryItem) -> Int {
        if workState.isSyncing(item.fullName) { return 0 }
        if settingsState.archiveEnabled && workState.isActive(item.fullName) && daysUntilArchive(for: item) <= 3 { return 1 }
        if workState.isActive(item.fullName) { return 2 }
        if workState.isArchived(item.fullName) { return 3 }
        return 4
    }

    private func stateRank(_ item: RepositoryItem) -> Int {
        if workState.isSyncing(item.fullName) { return 0 }
        if workState.isActive(item.fullName) { return 1 }
        if workState.isArchived(item.fullName) { return 2 }
        return 3
    }

    private func daysUntilArchive(for item: RepositoryItem) -> Int {
        if !settingsState.archiveEnabled {
            return Int.max
        }
        if let local: RepositoryLocalState = workState.localState(for: item.fullName) {
            return local.daysUntilArchive
        }
        return settingsState.daysToArchive
    }

    var body: some View {
        ZStack {
            VStack(spacing: AlembicGlassTokens.panelSpacing) {
                commandBar
                content
            }
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
            if state.repositories.isEmpty {
                loadingState
            } else {
                readyState
            }
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

    private var commandBrand: some View {
        HStack(spacing: 9) {
            Image(systemName: "drop.degreesign")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.linearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            VStack(alignment: .leading, spacing: 0) {
                Text("Alembic")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(commandSubtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var commandBar: some View {
        commandBarWide
        .frame(minHeight: AlembicGlassTokens.commandHeight)
        .alembicGlassSurface(.toolbar)
    }

    private var commandBarWide: some View {
        HStack(spacing: 10) {
            commandBrand
                .frame(width: 126, alignment: .leading)

            searchControl
                .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)

            stateMenu
                .frame(width: 102)

            sortMenu
                .frame(width: 108)

            if availableOwners.count > 1 {
                ownerMenu
                    .frame(width: 104)
            }

            Spacer(minLength: 8)

            toolbarActions
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 8) {
            AlembicGlassIconButton(systemImage: "arrow.clockwise", help: "Refresh") {
                AlembicRepositoryWorkBridge.shared.rescan()
                onRefresh()
            }
            AlembicGlassIconButton(systemImage: "square.and.arrow.down.on.square", help: "Import repositories", action: onImport)
            AlembicGlassIconButton(systemImage: "gearshape", help: "Settings", action: onSettings)
            AlembicGlassIconButton(systemImage: "info.circle", help: "Runtime info", action: onRuntimeInfo)
            AlembicGlassIconButton(
                systemImage: diagnosticsVisible ? "stethoscope.circle.fill" : "stethoscope",
                help: diagnosticsVisible ? "Hide diagnostics" : "Show diagnostics",
                isActive: diagnosticsVisible,
                action: onDiagnostics
            )
        }
    }

    private var stateMenu: some View {
        Menu {
            Button("All") { stateFilter = "all" }
            Divider()
            Button("Active (\(workState.activeRepositories.count))") { stateFilter = "active" }
            Button("Archived (\(workState.archivedRepositories.count))") { stateFilter = "archived" }
            Button("Cloud only") { stateFilter = "cloud" }
            Button("Syncing (\(workState.syncingRepositories.count))") { stateFilter = "syncing" }
        } label: {
            Label(stateFilterLabel, systemImage: stateFilterIcon)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
    }

    private var sortMenu: some View {
        Menu {
            Button("Needs attention") { sortMode = "attention" }
            Divider()
            if settingsState.archiveEnabled {
                Button("Archive soon") { sortMode = "archiveSoon" }
            }
            Button("Recently updated") { sortMode = "updated" }
            Button("State") { sortMode = "state" }
            Button("Name") { sortMode = "name" }
            Button("Owner") { sortMode = "owner" }
        } label: {
            Label(sortModeLabel, systemImage: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
    }

    private var searchControl: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
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
        .alembicGlassSurface(.control)
    }

    private var ownerMenu: some View {
        Menu {
            Button("All organizations") { ownerFilter = "" }
            Divider()
            ForEach(availableOwners, id: \.self) { owner in
                Button(owner) { ownerFilter = owner }
            }
        } label: {
            Label(ownerFilter.isEmpty ? "All orgs" : ownerFilter, systemImage: "building.2")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
    }

    private var commandSubtitle: String {
        if let primary: AccountItem = accountsState.primaryAccount {
            if let login: String = primary.login, !login.isEmpty {
                return "@\(login)"
            }
            return primary.name
        }
        if !state.accountLogin.isEmpty {
            return "@\(state.accountLogin)"
        }
        return "GitHub workspace command center"
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
            .alembicGlassSurface(.sheet)
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
            .alembicGlassSurface(.card)
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
        case "requesting_pages": return "Fetching pages"
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
            .alembicGlassSurface(.card)
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
                Button("Refresh") {
                    AlembicRepositoryWorkBridge.shared.rescan()
                    onRefresh()
                }
                    .buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: 360)
            .alembicGlassSurface(.card)
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
        GeometryReader { proxy in
            readyLayout(width: proxy.size.width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func readyLayout(width: CGFloat) -> some View {
        if width < 980 {
            VStack(spacing: AlembicGlassTokens.panelSpacing) {
                activityPanel
                    .frame(minHeight: 150)
                repositoryPanel
                    .layoutPriority(1)
            }
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: AlembicGlassTokens.panelSpacing) {
                    repositoryPanel
                        .layoutPriority(1)
                    activityPanel
                        .frame(width: min(320, max(280, width * 0.24)))
                }
            }
        }
    }

    private var repositoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repositories")
                        .font(.system(size: 15, weight: .semibold))
                    Text(repositoryPanelSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                }
            }

            repositoryStatsStrip

            if filteredRepositories.isEmpty {
                noResultsRow
            } else {
                repositoryList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alembicGlassSurface(
            .panel,
            padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        )
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity")
                    .font(.system(size: 15, weight: .semibold))
                Text(activitySubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if workState.workEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    activitySummaryRow(
                        title: "Archive",
                        value: settingsState.archiveEnabled ? "\(archiveSoonCount)" : "Off",
                        detail: settingsState.archiveEnabled ? "due soon" : "disabled",
                        systemImage: "hourglass",
                        tint: archiveSoonCount > 0 ? .orange : .secondary
                    )
                    activitySummaryRow(
                        title: "Local",
                        value: "\(workState.activeRepositories.count)",
                        detail: "ready to open",
                        systemImage: "checkmark.circle",
                        tint: .green
                    )
                    activitySummaryRow(
                        title: "Cloud",
                        value: "\(cloudOnlyCount)",
                        detail: "not cloned",
                        systemImage: "cloud",
                        tint: .secondary
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workState.workEntries.prefix(5)) { entry in
                        HStack(alignment: .center, spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.fullName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(entry.message.isEmpty ? entry.kind : entry.message)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .alembicGlassSurface(
                            .row,
                            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                        )
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .alembicGlassSurface(
            .panel,
            padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        )
    }

    private var repositoryStatsStrip: some View {
        HStack(spacing: 14) {
            ForEach(dashboardMetrics) { metric in
                repositoryStat(metric)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private func repositoryStat(_ metric: AlembicDashboardMetric) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(metric.value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(metric.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(metric.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help(metric.detail)
    }

    private func activitySummaryRow(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .layoutPriority(1)
        Spacer(minLength: 0)
        }
        .padding(10)
        .alembicGlassSurface(
            .row,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        )
    }

    private var dashboardMetrics: [AlembicDashboardMetric] {
        let total: Int = state.repositories.count
        let active: Int = workState.activeRepositories.count
        let archived: Int = workState.archivedRepositories.count
        let syncing: Int = workState.syncingRepositories.count
        let privateCount: Int = state.repositories.filter { $0.isPrivate }.count
        let forkCount: Int = state.repositories.filter { $0.isFork }.count

        return [
            AlembicDashboardMetric(
                id: "total",
                title: "Total",
                value: "\(total)",
                detail: state.isLoading ? "\(state.fetchedCount) fetched" : "repositories",
                systemImage: "square.stack.3d.up",
                tint: .accentColor
            ),
            AlembicDashboardMetric(
                id: "active",
                title: "Active",
                value: "\(active)",
                detail: "local",
                systemImage: "checkmark.circle.fill",
                tint: .green
            ),
            AlembicDashboardMetric(
                id: "archived",
                title: "Archived",
                value: "\(archived)",
                detail: "stored",
                systemImage: "archivebox.fill",
                tint: .blue
            ),
            AlembicDashboardMetric(
                id: "cloud",
                title: "Cloud",
                value: "\(cloudOnlyCount)",
                detail: "not cloned",
                systemImage: "cloud.fill",
                tint: .secondary
            ),
            AlembicDashboardMetric(
                id: "syncing",
                title: "Syncing",
                value: "\(syncing)",
                detail: syncing == 0 ? "no active jobs" : "jobs in flight",
                systemImage: "arrow.triangle.2.circlepath",
                tint: syncing == 0 ? .secondary : .orange
            ),
            AlembicDashboardMetric(
                id: "private",
                title: "Private",
                value: "\(privateCount)",
                detail: "\(forkCount) forks",
                systemImage: "lock.shield.fill",
                tint: .purple
            ),
        ]
    }

    private var cloudOnlyCount: Int {
        let total: Int = state.repositories.count
        return max(0, total - workState.activeRepositories.count - workState.archivedRepositories.count)
    }

    private var archiveSoonCount: Int {
        return state.repositories.filter { item in
            settingsState.archiveEnabled && workState.isActive(item.fullName) && daysUntilArchive(for: item) <= 3
        }.count
    }

    private var repositoryPanelSubtitle: String {
        if filteredRepositories.count == state.repositories.count {
            return "Sorted by \(sortModeLabel.lowercased())"
        }
        return "\(filteredRepositories.count) matching \(state.repositories.count) total"
    }

    private var activitySubtitle: String {
        if workState.workEntries.isEmpty {
            return "Idle"
        }
        return "\(workState.workEntries.count) active repository task\(workState.workEntries.count == 1 ? "" : "s")"
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

    private var sortModeLabel: String {
        switch sortMode {
        case "archiveSoon": return settingsState.archiveEnabled ? "Archive soon" : "Name"
        case "updated": return "Updated"
        case "state": return "State"
        case "name": return "Name"
        case "owner": return "Owner"
        default: return "Attention"
        }
    }

    private var repositoryCountLabel: String {
        let total: Int = state.repositories.count
        let shown: Int = filteredRepositories.count
        if state.isLoading {
            return "\(shown) shown  \(state.fetchedCount) fetched  loading"
        }
        if total == shown {
            return "\(workState.activeRepositories.count) active  \(workState.archivedRepositories.count) archived  \(total) repos"
        }
        return "\(shown) of \(total)"
    }

    private var repositoryList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(filteredRepositories) { item in
                    AlembicRepositoryRow(
                        item: item,
                        isActive: workState.isActive(item.fullName),
                        isArchived: workState.isArchived(item.fullName),
                        isSyncing: workState.isSyncing(item.fullName),
                        workEntries: workState.workForRepo(item.fullName),
                        localState: workState.localState(for: item.fullName),
                        archiveEnabled: settingsState.archiveEnabled,
                        daysToArchive: settingsState.daysToArchive,
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
    let isActive: Bool
    let isArchived: Bool
    let isSyncing: Bool
    let workEntries: [RepositoryWorkEntry]
    let localState: RepositoryLocalState?
    let archiveEnabled: Bool
    let daysToArchive: Int
    let onOpenBrowser: () -> Void
    let onShowDetail: () -> Void
    @State private var isHovering: Bool = false
    @State private var actionInFlight: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
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
                            .foregroundStyle(.secondary)
                    }
                    if item.isFork {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                rowSubtitle
            }
            Spacer(minLength: 12)
            if let action: String = actionInFlight {
                actionStatus(action)
            } else {
                rowBadges
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.row.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.row.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(isHovering ? 0.16 : 0.07), lineWidth: 0.5)
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
    private var rowSubtitle: some View {
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
        } else {
            Text(item.fullName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var rowBadges: some View {
        HStack(spacing: 6) {
            statusBadge
            if archiveEnabled && isActive && archiveDays <= 30 {
                badge(archiveTimingLabel, tint: archiveTimingColor)
            }
            if item.isArchived {
                badge("GitHub archived", tint: .secondary)
            }
        }
    }

    private var statusBadge: some View {
        if isSyncing {
            return badge("Syncing", tint: .accentColor)
        }
        if isActive {
            return badge("Active", tint: .green)
        }
        if isArchived {
            return badge("Archived", tint: .blue)
        }
        return badge("Cloud", tint: .secondary)
    }

    private var archiveTimingLabel: String {
        let days: Int = archiveDays
        if days <= 0 {
            return "Archive due"
        }
        if days == 1 {
            return "1d to archive"
        }
        return "\(days)d to archive"
    }

    private var archiveTimingColor: Color {
        let days: Int = archiveDays
        if days <= 3 {
            return .orange
        }
        return .secondary
    }

    private var archiveDays: Int {
        return localState?.daysUntilArchive ?? daysToArchive
    }

    private func actionStatus(_ action: String) -> some View {
        HStack(spacing: 5) {
            ProgressView()
                .scaleEffect(0.45)
                .frame(width: 10, height: 10)
            Text(action)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(tint.opacity(0.20), lineWidth: 0.5)
            )
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
            if archiveEnabled {
                Divider()
                Button("Archive") { runAction("archive") { AlembicRepositoryActionsBridge.shared.archive(fullName: item.fullName, completion: $0) } }
            }
        } else if isArchived {
            Button("Unarchive") { runAction("unarchive") { AlembicRepositoryActionsBridge.shared.unarchive(fullName: item.fullName, completion: $0) } }
            if archiveEnabled {
                Button("Update Archive") { runAction("updateArchive") { AlembicRepositoryActionsBridge.shared.updateArchive(fullName: item.fullName, completion: $0) } }
            }
            Button("Reveal in Finder") { runAction("openInFinder") { AlembicRepositoryActionsBridge.shared.openInFinder(fullName: item.fullName, completion: $0) } }
        } else {
            Button("Clone") { runAction("clone") { AlembicRepositoryActionsBridge.shared.clone(fullName: item.fullName, completion: $0) } }
            if archiveEnabled {
                Button("Archive from cloud") { runAction("archiveFromCloud") { AlembicRepositoryActionsBridge.shared.archiveFromCloud(fullName: item.fullName, completion: $0) } }
            }
        }
        Divider()
        Button("Fork & clone") { runAction("fork") { AlembicRepositoryActionsBridge.shared.fork(fullName: item.fullName, completion: $0) } }
        if archiveEnabled {
            Menu("Archive Master") {
                Button("Enroll") { runAction("enrollArchiveMaster") { AlembicRepositoryActionsBridge.shared.enrollArchiveMaster(fullName: item.fullName, completion: $0) } }
                Button("Refresh") { runAction("refreshArchiveMaster") { AlembicRepositoryActionsBridge.shared.refreshArchiveMaster(fullName: item.fullName, completion: $0) } }
                Button("Promote") { runAction("promoteArchiveMaster") { AlembicRepositoryActionsBridge.shared.promoteArchiveMaster(fullName: item.fullName, completion: $0) } }
                Divider()
                Button("Unenroll") { runAction("unenrollArchiveMaster") { AlembicRepositoryActionsBridge.shared.unenrollArchiveMaster(fullName: item.fullName, completion: $0) } }
            }
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
}
