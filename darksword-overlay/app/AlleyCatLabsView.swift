import SwiftUI

/// Research and privileged-device tools presented inside AlleyCat's existing
/// Settings navigation. This does not replace or wrap AlleyCat's home UI.
struct AlleyCatLabsView: View {
    var body: some View {
        List {
            Section("Research") {
                NavigationLink {
                    DarkSwordResearchWorkspaceView()
                } label: {
                    AlleyCatLabRow(
                        title: "Research Workspace",
                        subtitle: "Harnesses, bounded PoC runs, and experiment records",
                        systemImage: "scope"
                    )
                }

                NavigationLink {
                    DarkSwordCrashViewer()
                } label: {
                    AlleyCatLabRow(
                        title: "Crashes & Panics",
                        subtitle: "Read and classify available device diagnostics",
                        systemImage: "waveform.path.ecg.rectangle"
                    )
                }

                NavigationLink {
                    DarkSwordSourceEditorView()
                } label: {
                    AlleyCatLabRow(
                        title: "Source Editor",
                        subtitle: "Inspect and edit authorized project files",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )
                }
            }

            Section("Privileged Runtime") {
                NavigationLink {
                    DarkSwordToolApprovalView()
                } label: {
                    AlleyCatLabRow(
                        title: "Tool Approval",
                        subtitle: "Root daemon status and privileged-operation policy",
                        systemImage: "checkmark.shield.fill"
                    )
                }

                LabeledContent("Host socket", value: "/var/jb/var/run/darksword-rootd.sock")
                    .font(.caption)
            }

            Section("AlleyCat") {
                Text("The complete AlleyCat chat, model picker, conversations, voice, files, terminal, plugins, KittyStore, BuildKit, and Codex bridge remain the app's original interface.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AlleyCat Labs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AlleyCatLabRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
