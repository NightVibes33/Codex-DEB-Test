import Foundation
import SwiftUI
import UniformTypeIdentifiers
@_silgen_name("nyx_runtime_version")
private func nyxRuntimeVersionCString() -> UnsafePointer<CChar>

@MainActor
final class ViPhoneRuntimeModel: ObservableObject {
    enum Artifact: String, CaseIterable, Identifiable {
        case iBoot
        case kernelcache
        case deviceTree
        case trustCache
        case ramdisk

        var id: String { rawValue }

        var title: String {
            switch self {
            case .iBoot: "iBoot / iBEC payload"
            case .kernelcache: "Kernelcache"
            case .deviceTree: "Device Tree"
            case .trustCache: "Trust Cache"
            case .ramdisk: "Ramdisk"
            }
        }

        var fileName: String {
            switch self {
            case .iBoot: "iboot.bin"
            case .kernelcache: "kernelcache.bin"
            case .deviceTree: "devicetree.img4"
            case .trustCache: "trustcache.img4"
            case .ramdisk: "ramdisk.dmg"
            }
        }

        var required: Bool { self == .iBoot }
    }

    @Published var importTarget: Artifact?
    @Published var showingImporter = false
    @Published private(set) var fileSizes: [Artifact: Int64] = [:]
    @Published private(set) var statusText = "Runtime ready"
    @Published private(set) var detailText = "Import a decoded vresearch101 iBoot/iBEC payload to start."
    @Published private(set) var isBooting = false
    @Published private(set) var runtimeState: UInt32 = 0
    @Published private(set) var retiredInstructions: UInt64 = 0
    @Published private(set) var handledSyscalls: UInt64 = 0
    @Published private(set) var rejectedSyscalls: UInt64 = 0
    @Published private(set) var committedBytes: UInt64 = 0

    private var session: VirtualPhoneSession?
    private let fileManager = FileManager.default

    init() {
        try? fileManager.createDirectory(at: firmwareDirectory, withIntermediateDirectories: true)
        refreshFiles()
        do {
            session = try VirtualPhoneSession(manifest: Self.defaultManifest)
            updateCounters()
        } catch {
            statusText = "Runtime initialization failed"
            detailText = error.localizedDescription
        }
    }

    var canBoot: Bool { fileSizes[.iBoot] != nil && !isBooting }

    func choose(_ artifact: Artifact) {
        importTarget = artifact
        showingImporter = true
    }

    func handleImport(_ result: Result<[URL], Error>) {
        defer { importTarget = nil }
        guard let artifact = importTarget else { return }
        do {
            let urls = try result.get()
            guard let source = urls.first else { return }
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            try fileManager.createDirectory(at: firmwareDirectory, withIntermediateDirectories: true)
            let destination = url(for: artifact)
            let temporary = firmwareDirectory.appendingPathComponent(".\(artifact.fileName).import-\(UUID().uuidString)")
            try? fileManager.removeItem(at: temporary)
            try fileManager.copyItem(at: source, to: temporary)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporary, to: destination)
            refreshFiles()
            statusText = "\(artifact.title) imported"
            detailText = destination.lastPathComponent
        } catch {
            statusText = "Import failed"
            detailText = error.localizedDescription
        }
    }

    func remove(_ artifact: Artifact) {
        try? fileManager.removeItem(at: url(for: artifact))
        refreshFiles()
        statusText = "\(artifact.title) removed"
        detailText = artifact.required ? "Import iBoot again before booting." : "Optional boot artifact removed."
    }

    func boot() {
        guard canBoot else { return }
        guard let session else {
            statusText = "Runtime unavailable"
            return
        }

        do {
            let artifacts = try loadArtifacts()
            try session.stageBootArtifacts(artifacts)
            session.setInstructionBudget(2_000_000)
            updateCounters()
            isBooting = true
            statusText = "Booting virtual iPhone"
            detailText = "Executing at 0x7006C000 with the custom AArch64 runtime."

            Task {
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try session.boot()
                    }.value
                    self.statusText = "Guest execution yielded"
                    self.detailText = "The current CPU core stopped or reached its execution budget."
                } catch {
                    self.statusText = "Guest execution stopped"
                    self.detailText = error.localizedDescription
                }
                self.isBooting = false
                self.updateCounters()
            }
        } catch {
            statusText = "Boot staging failed"
            detailText = error.localizedDescription
            isBooting = false
            updateCounters()
        }
    }

    func stop() {
        session?.stop()
        isBooting = false
        statusText = "Stop requested"
        detailText = "The interpreter will return to the ViPhone host."
        updateCounters()
    }

    func resetSession() {
        if isBooting { session?.stop() }
        session = nil
        do {
            session = try VirtualPhoneSession(manifest: Self.defaultManifest)
            statusText = "Runtime reset"
            detailText = "Sparse guest memory and CPU state were recreated."
        } catch {
            statusText = "Runtime reset failed"
            detailText = error.localizedDescription
        }
        isBooting = false
        updateCounters()
    }

    func sizeText(for artifact: Artifact) -> String {
        guard let bytes = fileSizes[artifact] else { return artifact.required ? "Required" : "Optional" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func updateCounters() {
        runtimeState = session?.state ?? 0
        retiredInstructions = session?.instructionsRetired ?? 0
        handledSyscalls = session?.syscallsHandled ?? 0
        rejectedSyscalls = session?.syscallsRejected ?? 0
        committedBytes = session?.committedGuestBytes ?? 0
    }

    private func refreshFiles() {
        var sizes: [Artifact: Int64] = [:]
        for artifact in Artifact.allCases {
            let path = url(for: artifact).path
            if let attributes = try? fileManager.attributesOfItem(atPath: path),
               let size = attributes[.size] as? NSNumber {
                sizes[artifact] = size.int64Value
            }
        }
        fileSizes = sizes
    }

    private func loadArtifacts() throws -> VPhoneBootArtifacts {
        let iBootURL = url(for: .iBoot)
        guard fileManager.fileExists(atPath: iBootURL.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: iBootURL.path])
        }

        func data(_ artifact: Artifact) throws -> Data? {
            let file = url(for: artifact)
            guard fileManager.fileExists(atPath: file.path) else { return nil }
            return try Data(contentsOf: file, options: .mappedIfSafe)
        }

        return VPhoneBootArtifacts(
            iBoot: try Data(contentsOf: iBootURL, options: .mappedIfSafe),
            kernelcache: try data(.kernelcache),
            deviceTree: try data(.deviceTree),
            trustCache: try data(.trustCache),
            ramdisk: try data(.ramdisk)
        )
    }

    private var firmwareDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ViPhone/DefaultPhone/Firmware", isDirectory: true)
    }

    private func url(for artifact: Artifact) -> URL {
        firmwareDirectory.appendingPathComponent(artifact.fileName)
    }

    private static let defaultManifest = VPhoneMachineManifest(
        platformType: "vresearch101",
        cpuCount: 8,
        guestPhysicalMemorySize: 8 * 1024 * 1024 * 1024,
        screen: .iPhone,
        firmware: .init(
            bootROM: "Firmware/iboot.bin",
            sepROM: "Firmware/sep-rom.bin",
            sepStorage: "Firmware/sep-storage.bin",
            nvram: "Firmware/nvram.bin",
            disk: "Firmware/disk.img",
            machineIdentifier: "Firmware/machine-identifier.bin"
        )
    )
}

struct ViPhoneRuntimePanel: View {
    @StateObject private var model = ViPhoneRuntimeModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Engine", value: "Custom AArch64")
                    LabeledContent("NyxRuntime", value: String(cString: nyxRuntimeVersionCString()))
                    LabeledContent("Nyxian", value: "not booted")
                    LabeledContent("Guest platform", value: "vresearch101")
                    LabeledContent("Kernel surface", value: "Nyxian ABI")
                    LabeledContent("QEMU", value: "None")
                    LabeledContent("Companion PC", value: "Not required")
                } header: {
                    Text("ViPhone")
                } footer: {
                    Text("Apple firmware is not bundled. Imported artifacts remain inside ViPhone's app container.")
                }

                Section("Apple boot artifacts") {
                    ForEach(ViPhoneRuntimeModel.Artifact.allCases) { artifact in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artifact.title)
                                Text(model.sizeText(for: artifact))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.fileSizes[artifact] != nil {
                                Button("Replace") { model.choose(artifact) }
                                    .buttonStyle(.borderless)
                                Button(role: .destructive) { model.remove(artifact) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Button("Import") { model.choose(artifact) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("Runtime") {
                    LabeledContent("State", value: String(model.runtimeState))
                    LabeledContent("Instructions", value: model.retiredInstructions.formatted())
                    LabeledContent("Syscalls handled", value: model.handledSyscalls.formatted())
                    LabeledContent("Syscalls rejected", value: model.rejectedSyscalls.formatted())
                    LabeledContent(
                        "Committed guest RAM",
                        value: ByteCountFormatter.string(fromByteCount: Int64(clamping: model.committedBytes), countStyle: .memory)
                    )

                    HStack {
                        Button {
                            model.boot()
                        } label: {
                            Label("Boot", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canBoot)

                        if model.isBooting {
                            Button(role: .destructive) {
                                model.stop()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                        Button("Reset") { model.resetSession() }
                    }
                }

                Section("Last event") {
                    Text(model.statusText).font(.headline)
                    Text(model.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("ViPhone Runtime")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $model.showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: model.handleImport
        )
    }
}

struct ViPhoneRuntimeOverlay: ViewModifier {
    @State private var showingRuntime = false

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            Button {
                showingRuntime = true
            } label: {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Open ViPhone Runtime")
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $showingRuntime) {
            ViPhoneRuntimePanel()
        }
    }
}
