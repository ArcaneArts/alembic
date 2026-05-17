import SwiftUI

struct AlembicImportSheet: View {
    @ObservedObject var state: WorkspaceBridgeState
    let onClose: () -> Void
    let onChooseFolder: () -> Void
    let onScan: (String) -> Void
    let onImport: (String, [String]) -> Void

    @State private var pickedPath: String = ""
    @State private var selectedSlugs: Set<String> = []
    @State private var filterText: String = ""
    @State private var showOnlyGitHub: Bool = true
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if let outcome: WorkspaceBridgeState.ScanOutcome = state.lastScanResult {
                resultsView(outcome)
            } else {
                emptyView
            }
            Divider()
            footerView
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 560, idealHeight: 680)
        .padding(18)
        .alembicGlassSurface(.sheet)
        .background(AlembicSpikeBackground().ignoresSafeArea())
        .onAppear {
            pickedPath = state.workspacePath
        }
    }

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Import Existing Repositories")
                    .font(.system(size: 17, weight: .semibold))
                Text("Point Alembic at a folder containing your local git clones.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    private var emptyView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Select a folder to scan")
                .font(.system(size: 18, weight: .semibold))
            Text("Alembic looks for `.git` folders up to 4 levels deep. The expected structure is `<owner>/<repository>/.git`.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                TextField("Path to scan", text: $pickedPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(state.isScanning)
                Button {
                    onChooseFolder()
                } label: {
                    Label("Browse...", systemImage: "folder.badge.questionmark")
                }
                .controlSize(.regular)
                .disabled(state.isScanning)
            }
            .frame(maxWidth: 560)

            if state.isScanning {
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(state.scanProgress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button {
                    if !pickedPath.isEmpty {
                        onScan(pickedPath)
                    }
                } label: {
                    Label("Scan Folder", systemImage: "magnifyingglass")
                        .frame(minWidth: 140)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(pickedPath.isEmpty)
            }

            if let error: String = state.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private func resultsView(_ outcome: WorkspaceBridgeState.ScanOutcome) -> some View {
        VStack(spacing: 0) {
            resultsHeader(outcome)
            Divider()
            resultsFilters
            Divider()
            resultsList(outcome)
        }
    }

    private func resultsHeader(_ outcome: WorkspaceBridgeState.ScanOutcome) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.rootPath)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(outcome.totalGitRepos) git, \(outcome.gitHubRepos) GitHub - \(outcome.directoriesVisited) dirs in \(outcome.durationMs)ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onChooseFolder()
            } label: {
                Label("Change Folder", systemImage: "folder")
            }
            .controlSize(.small)

            Button {
                onScan(outcome.rootPath)
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .disabled(state.isScanning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var resultsFilters: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter by owner, name, or path", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))

            Toggle(isOn: $showOnlyGitHub) {
                Text("Only GitHub repos")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                let filtered: [WorkspaceBridgeState.DiscoveredRepoView] = filteredRepos
                if selectedSlugs.count == filtered.count && !filtered.isEmpty {
                    selectedSlugs.removeAll()
                } else {
                    selectedSlugs = Set(filtered.compactMap { repo in repo.slug ?? repo.absolutePath })
                }
            } label: {
                let filtered: [WorkspaceBridgeState.DiscoveredRepoView] = filteredRepos
                let allSelected: Bool = selectedSlugs.count == filtered.count && !filtered.isEmpty
                Text(allSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 12))
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var filteredRepos: [WorkspaceBridgeState.DiscoveredRepoView] {
        guard let outcome: WorkspaceBridgeState.ScanOutcome = state.lastScanResult else {
            return []
        }
        let query: String = filterText.trimmingCharacters(in: .whitespaces).lowercased()
        return outcome.repos.filter { repo in
            if showOnlyGitHub && !repo.isGitHub {
                return false
            }
            if query.isEmpty {
                return true
            }
            let combined: String = "\(repo.slug ?? "")|\(repo.relativePath)|\(repo.absolutePath)|\(repo.remoteUrl ?? "")".lowercased()
            return combined.contains(query)
        }
    }

    private func resultsList(_ outcome: WorkspaceBridgeState.ScanOutcome) -> some View {
        let repos: [WorkspaceBridgeState.DiscoveredRepoView] = filteredRepos
        return ScrollView {
            LazyVStack(spacing: 6) {
                if repos.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("No matching repositories")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(40)
                        Spacer()
                    }
                } else {
                    ForEach(repos) { repo in
                        repoRow(repo)
                    }
                }

                ForEach(outcome.warnings, id: \.self) { warning in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.06))
                    .cornerRadius(6)
                }
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.04))
    }

    private func repoRow(_ repo: WorkspaceBridgeState.DiscoveredRepoView) -> some View {
        let slugKey: String = repo.slug ?? repo.absolutePath
        let isSelected: Bool = selectedSlugs.contains(slugKey)
        return HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { selectedSlugs.contains(slugKey) },
                set: { newValue in
                    if newValue {
                        selectedSlugs.insert(slugKey)
                    } else {
                        selectedSlugs.remove(slugKey)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: repo.isGitHub ? "g.circle.fill" : "circle.dotted")
                .font(.system(size: 16))
                .foregroundStyle(repo.isGitHub ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if let slug: String = repo.slug {
                    Text(slug)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Text(repo.relativePath)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 6) {
                    if let url: String = repo.remoteUrl {
                        Text(url)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No remote configured")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    if let branch: String = repo.defaultBranch, !branch.isEmpty {
                        Text("- \(branch)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }

            Spacer()

            if !repo.isGitHub {
                Text("Not GitHub")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedSlugs.contains(slugKey) {
                selectedSlugs.remove(slugKey)
            } else {
                selectedSlugs.insert(slugKey)
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            if !statusMessage.isEmpty {
                Image(systemName: statusMessage.lowercased().contains("error") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(statusMessage.lowercased().contains("error") ? Color.red : Color.green)
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") {
                onClose()
            }
            .controlSize(.regular)
            .keyboardShortcut(.cancelAction)

            if let outcome: WorkspaceBridgeState.ScanOutcome = state.lastScanResult {
                Button {
                    let selected: [String] = Array(selectedSlugs)
                    onImport(outcome.rootPath, selected)
                } label: {
                    Label("Import \(selectedSlugs.count) Selected", systemImage: "tray.and.arrow.down.fill")
                        .frame(minWidth: 180)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(selectedSlugs.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }
}
