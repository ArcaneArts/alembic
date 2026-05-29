import AppKit
import SwiftUI

struct AlembicDiagnosticsConsole: View {
    @ObservedObject var state: AlembicDiagnosticsState
    @State private var levelFilter: String = "all"
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            filterBar
            logBody
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .alembicGlassSurface(
            .panel,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Live Diagnostics")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Real-time stream of Dart and Swift runtime events")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                pill(label: "total", value: "\(state.totalCount)", tint: .secondary)
                pill(label: "warn", value: "\(state.warnCount)", tint: state.warnCount > 0 ? .orange : .secondary)
                pill(label: "error", value: "\(state.errorCount)", tint: state.errorCount > 0 ? .red : .secondary)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $levelFilter) {
                Text("All").tag("all")
                Text("Errors").tag("error")
                Text("Warnings").tag("warn")
                Text("Info").tag("info")
                Text("Trace").tag("trace")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            TextField("Filter messages", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button {
                copyLogsToPasteboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Copy filtered log to clipboard")
        }
    }

    private var logBody: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredEntries()) { entry in
                        AlembicLogRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .onChange(of: state.entries.count) { _ in
                guard autoScroll, let last: AlembicLogEntry = state.entries.last else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func filteredEntries() -> [AlembicLogEntry] {
        let trimmed: String = searchText.trimmingCharacters(in: .whitespaces)
        let needle: String = trimmed.lowercased()
        return state.entries.filter { entry in
            if levelFilter != "all" && entry.level != levelFilter {
                return false
            }
            if needle.isEmpty {
                return true
            }
            if entry.tag.lowercased().contains(needle) {
                return true
            }
            if entry.message.lowercased().contains(needle) {
                return true
            }
            return false
        }
    }

    private func copyLogsToPasteboard() {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let lines: [String] = filteredEntries().map { entry in
            return "[\(formatter.string(from: entry.date))] [\(entry.level.uppercased())] [\(entry.tag)] \(entry.message)"
        }
        let payload: String = lines.joined(separator: "\n")
        let pasteboard: NSPasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    private func pill(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 0.5)
        )
    }
}

private struct AlembicLogRow: View {
    let entry: AlembicLogEntry

    private static let timeFormatter: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(AlembicLogRow.timeFormatter.string(from: entry.date))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.85))
                .frame(width: 84, alignment: .leading)
            Text(entry.level.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(levelColor)
                .frame(width: 56, alignment: .leading)
            Text(entry.tag)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case "error":
            return .red
        case "warn":
            return .orange
        case "success":
            return .green
        case "trace":
            return .secondary.opacity(0.7)
        default:
            return .secondary
        }
    }
}
