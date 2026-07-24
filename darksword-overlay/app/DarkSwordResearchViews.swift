import Darwin
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

                Section("Approval-gated workflow") {
                    Label("Inspect and classify crashes", systemImage: "1.circle")
                    Label("Generate a minimal reproducer", systemImage: "2.circle")
                    Label("Queue an exact privileged command", systemImage: "3.circle")
                    Label("Review and approve it on-device", systemImage: "4.circle")
                    Label("Retry once and store the audit record", systemImage: "5.circle")
                }

                Section("Full AlleyCat engine") {
                    Text("Chat, models, plugins, voice, terminal, Files, Git, KittyStore, SideStore, BuildKit, Watch, and the Codex bridge remain available in AlleyCat's original interface.")
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
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No crash logs indexed")
                            .font(.headline)
                        Text(errorMessage ?? "Pull to refresh or tap Reload.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
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

private struct DarkSwordPendingApproval: Equatable {
    let hash: UInt64
    let timeoutMilliseconds: UInt32
    let cwd: String
    let command: String
    let approved: Bool

    var hashLabel: String { String(format: "%016llx", hash) }
}

private enum DarkSwordApprovalClient {
    private static let socketPath = "/var/jb/var/run/darksword-rootd.sock"

    private enum ClientError: LocalizedError {
        case unavailable(String)
        case invalidResponse
        case daemon(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): return message
            case .invalidResponse: return "The root daemon returned an invalid approval response."
            case .daemon(let message): return message
            }
        }
    }

    static func status() throws -> DarkSwordPendingApproval? {
        let response = try transact(magic: "DSS1")
        var values: [String: String] = [:]
        for line in response.split(separator: "\n", omittingEmptySubsequences: true) {
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            values[String(pair[0])] = String(pair[1])
        }
        guard values["pending"] == "1" else { return nil }
        guard let hashText = values["hash"],
              let hash = UInt64(hashText, radix: 16),
              let timeoutText = values["timeout_ms"],
              let timeout = UInt32(timeoutText) else {
            throw ClientError.invalidResponse
        }
        return DarkSwordPendingApproval(
            hash: hash,
            timeoutMilliseconds: timeout,
            cwd: values["cwd"] ?? "",
            command: values["command"] ?? "",
            approved: values["approved"] == "1"
        )
    }

    static func approve(hash: UInt64) throws -> String {
        try transact(magic: "DSA1", hash: hash)
    }

    static func deny(hash: UInt64) throws -> String {
        try transact(magic: "DSD1", hash: hash)
    }

    private static func transact(magic: String, hash: UInt64? = nil) throws -> String {
        guard magic.utf8.count == 4 else { throw ClientError.invalidResponse }
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw ClientError.unavailable("Unable to open the local approval socket: \(String(cString: strerror(errno)))")
        }
        defer { Darwin.close(descriptor) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        let copied = socketPath.withCString { source in
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
                    strlcpy(destination, source, capacity)
                }
            }
        }
        guard copied < capacity else {
            throw ClientError.unavailable("The root daemon socket path is too long.")
        }

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            throw ClientError.unavailable("Root daemon unavailable: \(String(cString: strerror(errno)))")
        }

        var request = Data(magic.utf8)
        if var littleEndianHash = hash?.littleEndian {
            Swift.withUnsafeBytes(of: &littleEndianHash) { request.append(contentsOf: $0) }
        }
        try writeAll(request, to: descriptor)

        let header = try readExactly(12, from: descriptor)
        guard String(data: header.prefix(4), encoding: .utf8) == "DSO1" else {
            throw ClientError.invalidResponse
        }
        let exitCode = Int32(bitPattern: readUInt32(header, offset: 4))
        let outputLength = Int(readUInt32(header, offset: 8))
        guard outputLength >= 0 && outputLength <= 1_048_576 else {
            throw ClientError.invalidResponse
        }
        let output = try readExactly(outputLength, from: descriptor)
        let text = String(data: output, encoding: .utf8) ?? ""
        guard exitCode == 0 else {
            throw ClientError.daemon(text.isEmpty ? "The root daemon rejected the approval request." : text)
        }
        return text
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            (UInt32(data[offset + 1]) << 8) |
            (UInt32(data[offset + 2]) << 16) |
            (UInt32(data[offset + 3]) << 24)
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        var offset = 0
        while offset < data.count {
            let written = data.withUnsafeBytes { bytes in
                Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), data.count - offset)
            }
            if written < 0 {
                if errno == EINTR { continue }
                throw ClientError.unavailable("Approval request write failed: \(String(cString: strerror(errno)))")
            }
            if written == 0 { throw ClientError.invalidResponse }
            offset += written
        }
    }

    private static func readExactly(_ count: Int, from descriptor: Int32) throws -> Data {
        guard count > 0 else { return Data() }
        var bytes = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let received = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(descriptor, buffer.baseAddress!.advanced(by: offset), count - offset)
            }
            if received < 0 {
                if errno == EINTR { continue }
                throw ClientError.unavailable("Approval response read failed: \(String(cString: strerror(errno)))")
            }
            if received == 0 { throw ClientError.invalidResponse }
            offset += received
        }
        return Data(bytes)
    }
}

struct DarkSwordToolApprovalView: View {
    @State private var socketReady = false
    @State private var refreshedAt = Date()
    @State private var pendingRequest: DarkSwordPendingApproval?
    @State private var statusMessage = "No command waiting for approval."
    @State private var showApprovalConfirmation = false

    private let socketPath = "/var/jb/var/run/darksword-rootd.sock"

    var body: some View {
        NavigationStack {
            List {
                Section("Privileged tool service") {
                    LabeledContent("Daemon", value: socketReady ? "Connected" : "Unavailable")
                    LabeledContent("Socket", value: socketPath)
                    LabeledContent("Checked", value: refreshedAt.formatted(date: .omitted, time: .standard))
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Exact command approval") {
                    if let pendingRequest {
                        LabeledContent("State", value: pendingRequest.approved ? "Approved once" : "Waiting")
                        LabeledContent("Hash", value: pendingRequest.hashLabel)
                            .font(.caption.monospaced())
                        LabeledContent("Working directory", value: pendingRequest.cwd)
                            .font(.caption.monospaced())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Command")
                                .font(.caption.bold())
                            Text(pendingRequest.command)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        if pendingRequest.approved {
                            Label("Approved for one retry within 120 seconds", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Approve This Exact Command Once") {
                                showApprovalConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Deny Command", role: .destructive, action: denyPending)
                        }
                    } else {
                        Label("No command waiting", systemImage: "checkmark.shield")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Access after approval") {
                    Label("No filesystem path allowlist", systemImage: "externaldrive.fill")
                    Label("Read, create, modify, move, and delete files as root", systemImage: "folder.badge.gearshape")
                    Label("Process, service, Git, compiler, debugger, and package tools", systemImage: "terminal.fill")
                    Label("Privileged bounded research and PoC execution", systemImage: "waveform.path.ecg.rectangle")
                }

                Section("Emergency stop") {
                    Text("Only commands whose direct purpose is whole-device or raw-storage destruction remain non-executable. Every other privileged command is controlled by the exact on-device approval above and recorded in /var/jb/var/log/darksword-rootd.log.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tool Approval")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", action: refresh)
                }
            }
            .onAppear(perform: refresh)
            .alert("Approve this exact root command?", isPresented: $showApprovalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Approve Once", role: .destructive, action: approvePending)
            } message: {
                Text(pendingRequest.map { "\($0.cwd)\n\n\($0.command)" } ?? "No command is waiting.")
            }
        }
    }

    private func refresh() {
        socketReady = FileManager.default.fileExists(atPath: socketPath)
        refreshedAt = Date()
        guard socketReady else {
            pendingRequest = nil
            statusMessage = "Install the rootless .deb and load darksword-rootd."
            return
        }
        do {
            pendingRequest = try DarkSwordApprovalClient.status()
            if let pendingRequest {
                statusMessage = pendingRequest.approved
                    ? "The exact command is approved. Retry it before approval expires."
                    : "Review the pending root command before approving it."
            } else {
                statusMessage = "No command waiting for approval."
            }
        } catch {
            pendingRequest = nil
            statusMessage = error.localizedDescription
        }
    }

    private func approvePending() {
        guard let pendingRequest else { return }
        do {
            statusMessage = try DarkSwordApprovalClient.approve(hash: pendingRequest.hash)
            refresh()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func denyPending() {
        guard let pendingRequest else { return }
        do {
            statusMessage = try DarkSwordApprovalClient.deny(hash: pendingRequest.hash)
            refresh()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
