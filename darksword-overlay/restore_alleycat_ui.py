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
        print("usage: restore_alleycat_ui.py LITTER_ROOT", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()

    project = root / "apps/ios/project.yml"
    project_text = project.read_text()
    project_text = project_text.replace("PRODUCT_NAME: DarkSwordAI", "PRODUCT_NAME: AlleyCat")
    project.write_text(project_text)

    info = root / "apps/ios/Sources/Litter/Info.plist"
    info_text = info.read_text()
    info_text = info_text.replace("DarkSword AI uses", "Alley Cãt uses")
    info_text = info_text.replace("DarkSword AI discovers", "Alley Cãt discovers")
    # The advanced fork already defines this display name. Reassert it after
    # every import so the package and app UI keep the actual rebrand.
    if "<key>CFBundleDisplayName</key>" in info_text:
        lines = info_text.splitlines()
        for index, line in enumerate(lines[:-1]):
            if "<key>CFBundleDisplayName</key>" in line:
                lines[index + 1] = "\t<string>Alley Cãt</string>"
                break
        info_text = "\n".join(lines) + ("\n" if info_text.endswith("\n") else "")
    info.write_text(info_text)

    app = root / "apps/ios/Sources/Litter/LitterApp.swift"
    app_text = app.read_text()
    app_text = replace_once(
        app_text,
        "            DarkSwordRootView()",
        "            ContentView()",
        "DarkSword root view",
    )
    app.write_text(app_text)

    settings = root / "apps/ios/Sources/Litter/Views/SettingsView.swift"
    settings_text = settings.read_text()
    if "alleyCatLabsSection" not in settings_text:
        settings_text = replace_once(
            settings_text,
            "                    localToolsSection\n                    petSection",
            "                    localToolsSection\n                    alleyCatLabsSection\n                    petSection",
            "Settings local tools section",
        )

        marker = "    private func openMainAppRoute(_ route: String) {"
        labs_section = '''    private var alleyCatLabsSection: some View {
        Section {
            NavigationLink {
                AlleyCatLabsView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "scope")
                        .foregroundColor(LitterTheme.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AlleyCat Labs")
                            .litterFont(.subheadline)
                            .foregroundColor(LitterTheme.textPrimary)
                        Text("Research, crashes, source editing, and root-tool approval")
                            .litterFont(.caption)
                            .foregroundColor(LitterTheme.textSecondary)
                    }
                }
            }
            .listRowBackground(LitterTheme.surface.opacity(0.88))
            .listRowSeparatorTint(LitterTheme.border.opacity(0.5))
        } header: {
            Text("On-Device Research")
                .foregroundColor(LitterTheme.textSecondary)
        }
    }

'''
        if marker not in settings_text:
            raise SystemExit("error: could not locate Settings route helper")
        settings_text = settings_text.replace(marker, labs_section + marker, 1)
    settings.write_text(settings_text)

    instructions = root / "shared/rust-bridge/codex-mobile-client/src/local_runtime_instructions.rs"
    instructions_text = instructions.read_text()
    instructions_text = instructions_text.replace(
        "inside DarkSword AI's local ChatGPT/Codex runtime",
        "inside Alley Cãt's local ChatGPT/Codex runtime",
    )
    instructions_text = instructions_text.replace(
        "Litter's persistent iSH Alpine Linux fakefs",
        "AlleyCat's persistent iSH Alpine Linux fakefs",
    )
    instructions_text = instructions_text.replace(
        "Litter's native Codex home",
        "AlleyCat's native Codex home",
    )
    instructions.write_text(instructions_text)

    if "DarkSwordRootView()" in app.read_text():
        raise SystemExit("error: replacement DarkSword tab shell is still the app root")
    if "ContentView()" not in app.read_text():
        raise SystemExit("error: AlleyCat ContentView is not the app root")
    if "AlleyCat Labs" not in settings.read_text():
        raise SystemExit("error: AlleyCat Labs Settings entry was not installed")

    print("Full AlleyCat UI restored; jailbreak research tools installed inside AlleyCat Settings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
