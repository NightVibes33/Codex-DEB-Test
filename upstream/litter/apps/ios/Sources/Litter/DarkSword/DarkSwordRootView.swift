import SwiftUI
import Perception

/// DarkSword is the product shell. The complete NightVibes Litter ContentView
/// remains the real chat/agent engine and is embedded without replacing its
/// Codex bridge, model picker, voice, plugins, terminal, files, or BuildKit.
struct DarkSwordRootView: View {
    @AppStorage("darksword.selectedSection") private var selectedSection = DarkSwordSection.chat.rawValue

    var body: some View {
        WithPerceptionTracking {
        TabView(selection: $selectedSection) {
            DarkSwordChatSurface()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(DarkSwordSection.chat.rawValue)

            DarkSwordResearchWorkspaceView()
                .tabItem { Label("Research", systemImage: "scope") }
                .tag(DarkSwordSection.research.rawValue)

            DarkSwordCrashViewer()
                .tabItem { Label("Crashes", systemImage: "waveform.path.ecg.rectangle") }
                .tag(DarkSwordSection.crashes.rawValue)

            DarkSwordSourceEditorView()
                .tabItem { Label("Source", systemImage: "chevron.left.forwardslash.chevron.right") }
                .tag(DarkSwordSection.source.rawValue)

            DarkSwordToolApprovalView()
                .tabItem { Label("Tools", systemImage: "checkmark.shield.fill") }
                .tag(DarkSwordSection.tools.rawValue)
        }
    
        }}
}

enum DarkSwordSection: String {
    case chat
    case research
    case crashes
    case source
    case tools
}

private struct DarkSwordChatSurface: View {
    @AppStorage("darksword.loginHintDismissed") private var loginHintDismissed = false

    var body: some View {
        WithPerceptionTracking {
        ZStack(alignment: .top) {
            // This is the full advanced Litter runtime from NightVibes33/litter.
            // It owns ChatGPT-account/Codex authentication, model selection,
            // conversations, streaming, file attachments and tool calls.
            ContentView()

            if !loginHintDismissed {
                DarkSwordLoginBanner {
                    loginHintDismissed = true
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    
        }}
}

private struct DarkSwordLoginBanner: View {
    @Environment(AppModel.self) private var appModel
    @State private var isWorking = false
    @State private var authError: String?

    let onDismiss: () -> Void

    private var localServer: AppServerSnapshot? {
        appModel.snapshot?.servers.first(where: \.isLocal)
    }

    var body: some View {
        WithPerceptionTracking {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use your ChatGPT account")
                        .font(.subheadline.weight(.semibold))
                    Text("OpenAI's official sign-in opens here. Choose Continue with Google.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button {
                    startChatGPTLogin()
                } label: {
                    HStack(spacing: 6) {
                        if isWorking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss login banner")
            }

            if let authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
        }
    
        }}

    /// Litter's ChatGPTOAuth implementation uses OpenAI's official
    /// https://chatgpt.com/auth/login origin and stores only the returned account
    /// tokens in Litter's existing secure account store.
    private func startChatGPTLogin() {
        guard !isWorking else { return }
        guard let localServer else {
            authError = "The local ChatGPT runtime is still starting. Try again after the connection indicator appears."
            return
        }

        Task { @MainActor in
            isWorking = true
            defer { isWorking = false }

            do {
                authError = nil
                try await appModel.loginLocalChatGPTAccount(serverId: localServer.serverId)
                onDismiss()
            } catch ChatGPTOAuthError.cancelled {
                return
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}
