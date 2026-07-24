import SwiftUI

struct DarkSwordResearchWorkspaceView: View {
    private let labRoot = "/var/jb/usr/share/darksword/jailbreak-lab"

    var body: some View {
        NavigationStack {
            List {
                Section("Jailbreak Lab") {
                    LabRow(title: "Fuzz harness templates", detail: "\(labRoot)/harnesses", icon: "aqi.medium")
                    LabRow(title: "PoC runner", detail: "\(labRoot)/bin/darksword-poc-run", icon: "play.square.stack")
                    LabRow(title: "Crash classifier", detail: "\(labRoot)/bin/darksword-crash-classify", icon: "waveform.path.ecg")
                    LabRow(title: "Experiment database", detail: "/var/mobile/Library/DarkSwordLab/experiments", icon: "cylinder.split.1x2")
                }

                Section("Bounded workflow") {
                    Label("Collect and classify crashes", systemImage: "1.circle")
                    Label("Generate a minimal reproducer", systemImage: "2.circle")
                    Label("Build and run with limits", systemImage: "3.circle")
                    Label("Store logs, diffs, and hashes", systemImage: "4.circle")
                    Label("Require local approval for privileged writes", systemImage: "5.circle")
                }

                Section("Full Litter engine") {
                    Text("Chat, models, plugins, voice, terminal, Files, Git, KittyStore, SideStore, BuildKit, Watch, and the Codex bridge remain available in the Chat tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Research Workspace")
        }
    }
}

private struct LabRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: icon)
        }
    }
}

struct DarkSwordCrashViewer: View {
    @State private var records: [DarkSwordCrashRecord] = []
    @State private var selected: DarkSwordCrashRecord?
    @State private var errorMessage: String?

    private let roots = [
        "/var/mobile/Library/Logs/CrashReporter",
        "/Library/Logs/CrashReporter",
        "/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs"
    ]

    var body: some View {
        NavigationStack {
            List(records) { record in
                Button {
                    selected = record
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.name)
                            .foregroundStyle(.primary)
                        Text(record.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView("No crash logs indexed", systemImage: "waveform.path.ecg", description: Text(errorMessage ?? "Pull to refresh or tap Reload."))
                }
            }
            .navigationTitle("Crashes & Panics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reload", action: reload)
                }
            }
            .refreshable { reload() }
            .onAppear(perform: reload)
            .sheet(item: $selected) { record in
                DarkSwordCrashDetail(record: record)
            }
        }
    }

    private func reload() {
        var found: [DarkSwordCrashRecord] = []
        let manager = FileManager.default
        for root in roots {
            guard let enumerator = manager.enumerator(atPath: root) else { continue }
            while let relative = enumerator.nextObject() as? String {
                let lower = relative.lowercased()
                guard lower.hasSuffix(".ips") || lower.hasSuffix(".panic") || lower.hasSuffix(".crash") else { continue }
                found.append(DarkSwordCrashRecord(path: root + "/" + relative))
                if found.count >= 500 { break }
            }
        }
        records = found.sorted { $0.modifiedAt > $1.modifiedAt }
        errorMessage = found.isEmpty ? "The app could not find readable .ips, .panic, or .crash files." : nil
    }
}

struct DarkSwordCrashRecord: Identifiable {
    let path: String
    var id: String { path }
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var modifiedAt: Date {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
    }
}

private struct DarkSwordCrashDetail: View {
    let record: DarkSwordCrashRecord
    @State private var text = "Loading…"

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(record.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                text = (try? String(contentsOfFile: record.path, encoding: .utf8)) ?? "Unable to read this log."
            }
        }
    }
}

struct DarkSwordSourceEditorView: View {
    @State private var path = "/var/mobile/Projects"
    @State private var contents = ""
    @State private var status = "Enter a text-file path and tap Read."
    @State private var pendingWrite = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                TextField("Absolute file path", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Read", action: readFile)
                        .buttonStyle(.bordered)
                    Button("Write") { pendingWrite = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                TextEditor(text: $contents)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    }
            }
            .padding()
            .navigationTitle("Source Editor")
            .alert("Write this file?", isPresented: $pendingWrite) {
                Button("Cancel", role: .cancel) {}
                Button("Write", role: .destructive, action: writeFile)
            } message: {
                Text(path)
            }
        }
    }

    private func readFile() {
        do {
            contents = try String(contentsOfFile: path, encoding: .utf8)
            status = "Read \(contents.utf8.count) bytes"
        } catch {
            status = "Read failed: \(error.localizedDescription)"
        }
    }

    private func writeFile() {
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            status = "Wrote \(contents.utf8.count) bytes"
        } catch {
            status = "Write failed: \(error.localizedDescription)"
        }
    }
}

struct DarkSwordToolApprovalView: View {
    @State private var socketReady = false
    @State private var refreshedAt = Date()

    private let socketPath = "/var/jb/var/run/darksword-rootd.sock"

    var body: some View {
        NavigationStack {
            List {
                Section("Privileged tool service") {
                    LabeledContent("Daemon", value: socketReady ? "Connected" : "Unavailable")
                    LabeledContent("Socket", value: socketPath)
                    LabeledContent("Checked", value: refreshedAt.formatted(date: .omitted, time: .standard))
                }

                Section("Automatic read tools") {
                    Label("Read files and directories", systemImage: "doc.text.magnifyingglass")
                    Label("Inspect processes, services, Git, crashes, and logs", systemImage: "eye")
                    Label("Run bounded builds and tests", systemImage: "hammer")
                }

                Section("Local approval required") {
                    Label("File writes and patch application", systemImage: "pencil.and.outline")
                    Label("Package and service changes", systemImage: "shippingbox")
                    Label("PoC execution with elevated privileges", systemImage: "exclamationmark.shield")
                }

                Section("Always blocked") {
                    Label("Credential extraction", systemImage: "key.slash")
                    Label("Device erasure or destructive disk commands", systemImage: "externaldrive.badge.xmark")
                    Label("Unattended persistence or kernel writes", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Tool Approval")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", action: refresh)
                }
            }
            .onAppear(perform: refresh)
        }
    }

    private func refresh() {
        socketReady = FileManager.default.fileExists(atPath: socketPath)
        refreshedAt = Date()
    }
}
