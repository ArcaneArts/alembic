import AppKit
import SwiftUI

struct AlembicSignInSheet: View {
    let onSubmit: (String, String, @escaping (AlembicRepositoryListBridge.SignInResult) -> Void) -> Void
    let onClose: () -> Void

    @State private var token: String = ""
    @State private var accountName: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String = ""

    private var canSubmit: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider().opacity(0.3)
            fields
            if !errorMessage.isEmpty {
                errorBanner
            }
            scopesHint
            footer
        }
        .padding(24)
        .frame(width: 500)
        .background(AlembicSpikeGlassPanel())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Connect GitHub")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text("Paste a Personal Access Token. Alembic stores it encrypted on this device and uses it for all GitHub API calls.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Personal access token")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                SecureField("ghp_... or github_pat_...", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .font(.system(size: 13, design: .monospaced))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Display name (optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Personal, Work, etc.", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .font(.system(size: 13))
            }
        }
    }

    private var scopesHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Required scopes:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("repo")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                )
            Text("read:org")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                )
            Spacer()
        }
    }

    private var errorBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 12, weight: .semibold))
            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.red.opacity(0.30), lineWidth: 0.5)
        )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                if let url: URL = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=Alembic") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                    Text("Generate new token")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) {
                onClose()
            }
            .buttonStyle(.bordered)
            .disabled(isSubmitting)
            .keyboardShortcut(.cancelAction)
            Button {
                submit()
            } label: {
                HStack(spacing: 5) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                    Text(isSubmitting ? "Connecting..." : "Connect")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func submit() {
        let trimmedToken: String = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName: String = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }
        errorMessage = ""
        isSubmitting = true
        onSubmit(trimmedToken, trimmedName) { result in
            isSubmitting = false
            if result.ok {
                token = ""
                accountName = ""
                onClose()
                return
            }
            errorMessage = result.errorMessage ?? "Sign-in failed."
        }
    }
}
