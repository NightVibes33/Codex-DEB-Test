import SwiftUI
import UIKit

/// DarkSword is the product shell. The complete NightVibes Litter ContentView
/// remains the real chat/agent engine and is embedded without replacing its
/// Codex bridge, model picker, voice, plugins, terminal, files, or BuildKit.
struct DarkSwordRootView: View {
    @AppStorage("darksword.selectedSection") private var selectedSection = DarkSwordSection.chat.rawValue

    var body: some View {
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
    }
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
    }
}

private struct DarkSwordLoginBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Use your ChatGPT account")
                    .font(.subheadline.weight(.semibold))
                Text("Continue with Google opens OpenAI's official sign-in page.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Google") {
                DarkSwordOpenAIAuth.openGoogleLogin()
            }
            .buttonStyle(.borderedProminent)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss login banner")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
        }
    }
}

enum DarkSwordOpenAIAuth {
    /// Authentication remains entirely on OpenAI's HTTPS origin. DarkSword
    /// never asks for, stores, or intercepts a Google password or ChatGPT cookie.
    static func openGoogleLogin() {
        guard let url = URL(string: "https://chatgpt.com/auth/login") else { return }
        UIApplication.shared.open(url, options: [:])
    }
}
