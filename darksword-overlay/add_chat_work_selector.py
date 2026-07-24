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
        case .chat: return "Conversation"
        case .work: return "Tools and agent work"
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
        "preferred chat runtime key",
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
    var chatModeDeveloperInstructions: String? {
        guard preferredChatWorkMode == .chat else { return nil }
        return "Respond as a conversational ChatGPT assistant. Use tools only when the user explicitly asks for tool use or when a tool is necessary to complete the request. Keep the normal AlleyCat model, account, files, and attachment support available."
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
        "AppState chat runtime initialization",
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
            Text("Mode")
                .litterFont(.caption2, weight: .bold)
                .foregroundStyle(LitterTheme.textMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(ChatWorkMode.allCases) { mode in
                    let selected = appState.preferredChatWorkMode == mode
                    Button {
                        appState.preferredChatWorkMode = mode
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
                    .accessibilityIdentifier("modelPicker.mode.\\(mode.rawValue)")
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

    home = root / "apps/ios/Sources/Litter/Views/HomeComposerView.swift"
    text = home.read_text()
    text = replace_once(
        text,
        '                    developerInstructions: nil,\n',
        '                    developerInstructions: appState.chatModeDeveloperInstructions,\n',
        "home thread developer instructions",
    )
    home.write_text(text)

    conversation = root / "apps/ios/Sources/Litter/Views/ConversationView.swift"
    text = conversation.read_text()
    text = replace_once(
        text,
        '            developerInstructions: nil,\n',
        '            developerInstructions: appState.chatModeDeveloperInstructions,\n',
        "conversation fork developer instructions",
    )
    conversation.write_text(text)

    checks = {
        app_state: ["enum ChatWorkMode", "preferredChatWorkMode", "chatModeDeveloperInstructions"],
        header: ["chatWorkSelector", 'Text("Chat")' if False else "ChatWorkMode.allCases"],
        home: ["developerInstructions: appState.chatModeDeveloperInstructions"],
        conversation: ["developerInstructions: appState.chatModeDeveloperInstructions"],
    }
    for path, needles in checks.items():
        current = path.read_text()
        for needle in needles:
            if needle not in current:
                raise SystemExit(f"error: missing {needle!r} in {path}")

    print("Added persistent Chat/Work selector to AlleyCat model picker; Work remains the default.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
