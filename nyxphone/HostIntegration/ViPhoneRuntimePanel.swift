import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VPhoneRuntimeCore
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
    @Published private(set) var statusText = "ViPhone ready"
    @Published private(set) var detailText = "Boot the built-in ViPhone guest or import user-supplied firmware."
    @Published private(set) var isBooting = false
    @Published private(set) var runtimeState: UInt32 = 0
    @Published private(set) var retiredInstructions: UInt64 = 0
    @Published private(set) var handledSyscalls: UInt64 = 0
    @Published private(set) var rejectedSyscalls: UInt64 = 0
    @Published private(set) var committedBytes: UInt64 = 0
    @Published private(set) var bundledBootLog = ""
    @Published private(set) var guestFrame: UIImage?
    @Published private(set) var persistentDiskBytes: Int64 = 0

    private var session: VirtualPhoneSession?
    private var bundledVM: OpaquePointer?
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

    deinit {
        if let bundledVM { nyx_vm_destroy(bundledVM) }
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

    var bundledKernelAvailable: Bool { bundledKernelURL != nil }

    func bootBundledNyxian() {
        guard let kernelURL = bundledKernelURL else {
            statusText = "ViPhone guest unavailable"
            detailText = "The built-in guest image is not present in this build."
            return
        }
        do {
            let image = try Data(contentsOf: kernelURL, options: .mappedIfSafe)
            var log = [CChar](repeating: 0, count: 4096)
            var logLength = 0
            var frame = [UInt8](repeating: 0, count: 64 * 96 * 4)
            var frameInfo = NyxFramebufferInfo(
                width: 0, height: 0, stride: 0, pixel_format: 0, byte_length: 0
            )
            if let bundledVM {
                nyx_vm_destroy(bundledVM)
                self.bundledVM = nil
            }
            let diskURL = try persistentDiskURL()
            let status: Int32 = diskURL.path.withCString { diskPath in
                image.withUnsafeBytes { imageBytes in
                    log.withUnsafeMutableBufferPointer { logBytes in
                    frame.withUnsafeMutableBytes { frameBytes in
                        nyx_vm_boot_kernel_device_storage(
                            imageBytes.baseAddress, imageBytes.count, 0x100000, 0x100000,
                            diskPath, 64 * 1024 * 1024,
                            logBytes.baseAddress, logBytes.count, &logLength,
                            frameBytes.baseAddress, frameBytes.count, &frameInfo, &bundledVM
                        )
                    }
                }
                }
            }
            if let attributes = try? fileManager.attributesOfItem(atPath: diskURL.path),
               let size = attributes[.size] as? NSNumber {
                persistentDiskBytes = size.int64Value
            }
            bundledBootLog = String(cString: log)
            try persistBootLog(bundledBootLog)
            guestFrame = Self.makeGuestImage(frame, info: frameInfo)
            if status == 0
                && guestFrame != nil
                && bundledBootLog.contains("[NYXIAN] kernel entry reached")
                && bundledBootLog.contains("[NYXDISPLAY] first frame")
                && bundledBootLog.contains("[NYXSTORAGE] root mounted")
                && bundledBootLog.contains("[NYXDARWIN] nyxinit started")
                && bundledBootLog.contains("hello from Nyxian userspace") {
                statusText = "ViPhone guest display active"
                detailText = bundledBootLog
            } else {
                statusText = "ViPhone boot failed"
                detailText = "status=\(status)\n\(bundledBootLog)"
            }
        } catch {
            statusText = "ViPhone boot failed"
            detailText = error.localizedDescription
        }
    }

    func resetPersistentStorage() {
        if let bundledVM {
            nyx_vm_destroy(bundledVM)
            self.bundledVM = nil
        }
        do {
            let diskURL = try persistentDiskURL()
            if fileManager.fileExists(atPath: diskURL.path) {
                try fileManager.removeItem(at: diskURL)
            }
            persistentDiskBytes = 0
            guestFrame = nil
            statusText = "ViPhone storage reset"
            detailText = "The default guest disk will be recreated on next boot."
        } catch {
            statusText = "Storage reset failed"
            detailText = error.localizedDescription
        }
    }

    func sendTouch(_ event: NyxTouchEvent) {
        guard let bundledVM else { return }
        var event = event
        var frame = [UInt8](repeating: 0, count: 64 * 96 * 4)
        var frameInfo = NyxFramebufferInfo(width: 0, height: 0, stride: 0, pixel_format: 0, byte_length: 0)
        let status = frame.withUnsafeMutableBytes { bytes in
            nyx_vm_touch_capture_frame(bundledVM, &event, bytes.baseAddress, bytes.count, &frameInfo)
        }
        if status == 0, let image = Self.makeGuestImage(frame, info: frameInfo) {
            guestFrame = image
            statusText = "ViPhone touch delivered"
        } else {
            statusText = "ViPhone touch failed"
            detailText = "status=\(status)"
        }
    }

    private static func makeGuestImage(_ bytes: [UInt8], info: NyxFramebufferInfo) -> UIImage? {
        guard info.pixel_format == 1, info.width > 0, info.height > 0,
              info.stride >= info.width * 4, info.byte_length <= UInt64(bytes.count) else { return nil }
        let data = Data(bytes.prefix(Int(info.byte_length)))
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: Int(info.width), height: Int(info.height),
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(info.stride),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: image)
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

    private func persistentDiskURL() throws -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ViPhone/VMs/default/disk", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("disk.img")
    }

    private var bundledKernelURL: URL? {
        Bundle.main.url(forResource: "Nyxian", withExtension: "bin", subdirectory: "ViPhoneGuest")
    }

    private func persistBootLog(_ log: String) throws {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ViPhone/Logs", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try log.write(to: directory.appendingPathComponent("boot.log"), atomically: true, encoding: .utf8)
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

struct GuestDisplayView: UIViewRepresentable {
    let image: UIImage
    let onTouch: (NyxTouchEvent) -> Void

    func makeUIView(context: Context) -> GuestFramebufferView {
        let view = GuestFramebufferView()
        view.onTouch = onTouch
        view.image = image
        return view
    }

    func updateUIView(_ view: GuestFramebufferView, context: Context) {
        view.onTouch = onTouch
        view.image = image
    }
}

final class GuestFramebufferView: UIView {
    private let imageView = UIImageView()
    private var touchIDs: [ObjectIdentifier: UInt32] = [:]
    private var nextTouchID: UInt32 = 1
    var onTouch: ((NyxTouchEvent) -> Void)?
    var image: UIImage? {
        didSet { imageView.image = image }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        clipsToBounds = true
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { emit(touches, phase: 0) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { emit(touches, phase: 1) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { emit(touches, phase: 2) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { emit(touches, phase: 2) }

    private func emit(_ touches: Set<UITouch>, phase: UInt32) {
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let displayedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (bounds.width - displayedSize.width) / 2, y: (bounds.height - displayedSize.height) / 2)
        for touch in touches {
            let key = ObjectIdentifier(touch)
            let id: UInt32
            if let existing = touchIDs[key] {
                id = existing
            } else {
                id = nextTouchID
                nextTouchID &+= 1
                touchIDs[key] = id
            }
            let location = touch.location(in: self)
            let x = Float(max(0, min(1, (location.x - origin.x) / displayedSize.width)))
            let y = Float(max(0, min(1, (location.y - origin.y) / displayedSize.height)))
            let pressure = touch.maximumPossibleForce > 0 ? Float(touch.force / touch.maximumPossibleForce) : 1
            onTouch?(NyxTouchEvent(id: id, x: x, y: y, pressure: pressure, phase: phase))
            if phase == 2 { touchIDs.removeValue(forKey: key) }
        }
    }
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

                Section("ViPhone Guest") {
                    LabeledContent(
                        "Built-in guest",
                        value: model.bundledKernelAvailable ? "Ready" : "Missing"
                    )
                    LabeledContent(
                        "Persistent disk",
                        value: model.persistentDiskBytes > 0
                            ? ByteCountFormatter.string(fromByteCount: model.persistentDiskBytes, countStyle: .file)
                            : "Created on first boot"
                    )
                    Button(role: .destructive) {
                        model.resetPersistentStorage()
                    } label: {
                        Label("Reset Guest Storage", systemImage: "externaldrive.badge.xmark")
                    }
                    .disabled(model.persistentDiskBytes == 0)
                    Button {
                        model.bootBundledNyxian()
                    } label: {
                        Label("Boot ViPhone", systemImage: "terminal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.bundledKernelAvailable)

                    if let frame = model.guestFrame {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Guest Display")
                                .font(.headline)
                            GuestDisplayView(image: frame, onTouch: model.sendTouch)
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                .frame(maxWidth: .infinity, minHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .accessibilityLabel("Interactive ViPhone guest display")
                        }
                    }

                    if !model.bundledBootLog.isEmpty {
                        Text(model.bundledBootLog)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
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
