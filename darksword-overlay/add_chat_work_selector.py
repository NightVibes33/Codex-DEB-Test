#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"error: could not locate {label}")
    return text.replace(old, new, 1)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: add_chat_work_selector.py LITTER_ROOT", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()

    app_state = root / "apps/ios/Sources/Litter/Models/AppState.swift"
    text = app_state.read_text()

    enum_block = '''enum ChatWorkMode: String, Codable, CaseIterable, Identifiable {
    case chat
    case work

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .work: return "Work"
        }
    }

    var subtitle: String {
        switch self {
        case .chat: return "Normal ChatGPT usage"
        case .work: return "Codex tools and agent usage"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .work: return "hammer"
        }
    }
}

'''
    text = replace_once(
        text,
        "enum ChatRuntimeMode: String, Codable, CaseIterable, Identifiable {\n",
        enum_block + "enum ChatRuntimeMode: String, Codable, CaseIterable, Identifiable {\n",
        "ChatRuntimeMode declaration",
    )

    text = replace_once(
        text,
        '    private static let preferredChatRuntimeKey = "litter.preferredChatRuntime"\n',
        '    private static let preferredChatRuntimeKey = "litter.preferredChatRuntime"\n'
        '    private static let preferredChatWorkModeKey = "alleycat.preferredChatWorkMode"\n',
        "preferred Chat/Work key",
    )

    property_block = '''    var preferredChatWorkModeRaw: String {
        didSet {
            UserDefaults.standard.set(preferredChatWorkModeRaw, forKey: Self.preferredChatWorkModeKey)
        }
    }
    var preferredChatWorkMode: ChatWorkMode {
        get { ChatWorkMode(rawValue: preferredChatWorkModeRaw) ?? .work }
        set { preferredChatWorkModeRaw = newValue.rawValue }
    }
'''
    text = replace_once(
        text,
        '    var preferredBridgeServerId: String {\n',
        property_block + '    var preferredBridgeServerId: String {\n',
        "preferred bridge server property",
    )

    text = replace_once(
        text,
        '        preferredChatRuntimeRaw = UserDefaults.standard.string(forKey: Self.preferredChatRuntimeKey) ?? ChatRuntimeMode.chatGPTAccount.rawValue\n',
        '        preferredChatRuntimeRaw = UserDefaults.standard.string(forKey: Self.preferredChatRuntimeKey) ?? ChatRuntimeMode.chatGPTAccount.rawValue\n'
        '        preferredChatWorkModeRaw = UserDefaults.standard.string(forKey: Self.preferredChatWorkModeKey) ?? ChatWorkMode.work.rawValue\n',
        "AppState Chat/Work initialization",
    )
    app_state.write_text(text)

    header = root / "apps/ios/Sources/Litter/Views/HeaderView.swift"
    text = header.read_text()
    text = replace_once(
        text,
        '''        VStack(spacing: 0) {
            runtimeSelector
            modelSearchField
''',
        '''        VStack(spacing: 0) {
            chatWorkSelector
            runtimeSelector
            modelSearchField
''',
        "model picker content stack",
    )

    selector_block = '''    private var chatWorkSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experience")
                .litterFont(.caption2, weight: .bold)
                .foregroundStyle(LitterTheme.textMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(ChatWorkMode.allCases) { mode in
                    let selected = appState.preferredChatWorkMode == mode
                    Button {
                        appState.preferredChatWorkMode = mode
                        if mode == .chat {
                            appState.showModelSelector = false
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: mode.systemImage)
                                .litterFont(size: 11, weight: .semibold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                    .litterFont(.caption2, weight: .bold)
                                Text(mode.subtitle)
                                    .litterFont(size: 9.5, weight: .medium)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            selected ? LitterTheme.accent : LitterTheme.surfaceLight,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(selected ? LitterTheme.textOnAccent : LitterTheme.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    selected ? LitterTheme.accentStrong.opacity(0.7) : LitterTheme.separator.opacity(0.8),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("modelPicker.experience.\\(mode.rawValue)")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

'''
    text = replace_once(
        text,
        '    private var runtimeSelector: some View {\n',
        selector_block + '    private var runtimeSelector: some View {\n',
        "runtime selector declaration",
    )
    header.write_text(text)

    app = root / "apps/ios/Sources/Litter/LitterApp.swift"
    text = app.read_text()
    cloud_route = '''        .fullScreenCover(
            isPresented: Binding(
                get: { appState.preferredChatWorkMode == .chat },
                set: { isPresented in
                    if !isPresented {
                        appState.preferredChatWorkMode = .work
                    }
                }
            )
        ) {
            ZStack(alignment: .topTrailing) {
                ChatGPTCloudChatView()
                    .ignoresSafeArea()

                Button {
                    appState.preferredChatWorkMode = .work
                } label: {
                    Label("Work", systemImage: "hammer.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .accessibilityIdentifier("chatgptCloud.returnToWork")
            }
        }
'''
    text = replace_once(
        text,
        '        .sheet(isPresented: $bindableAppState.showServerPicker) {\n',
        cloud_route + '        .sheet(isPresented: $bindableAppState.showServerPicker) {\n',
        "ContentView ChatGPT cloud route",
    )
    app.write_text(text)

    checks = {
        app_state: [
            "enum ChatWorkMode",
            "preferredChatWorkMode",
            "Normal ChatGPT usage",
            "Codex tools and agent usage",
        ],
        header: ["chatWorkSelector", "ChatWorkMode.allCases", "modelPicker.experience"],
        app: ["ChatGPTCloudChatView()", "chatgptCloud.returnToWork"],
    }
    for path, needles in checks.items():
        current = path.read_text()
        for needle in needles:
            if needle not in current:
                raise SystemExit(f"error: missing {needle!r} in {path}")

    for stale in (
        root / "apps/ios/Sources/Litter/Views/HomeComposerView.swift",
        root / "apps/ios/Sources/Litter/Views/ConversationView.swift",
    ):
        if "chatModeDeveloperInstructions" in stale.read_text():
            raise SystemExit(f"error: stale fake Chat routing remains in {stale}")

    print("Added real usage split: Chat opens official ChatGPT cloud; Work remains AlleyCat/Codex.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
