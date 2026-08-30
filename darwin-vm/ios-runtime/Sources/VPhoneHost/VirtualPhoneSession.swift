import Foundation
import VPhoneRuntimeCore

public enum VirtualPhoneSessionError: Error, LocalizedError {
    case runtimeCreationFailed
    case bootBackendUnavailable
    case runtimeFailure(Int32)

    public var errorDescription: String? {
        switch self {
        case .runtimeCreationFailed: "Could not create the native virtual-phone runtime."
        case .bootBackendUnavailable: "The vphone600ap machine is configured, but the ARM64 execution backend is not installed yet."
        case .runtimeFailure(let code): "Virtual-phone runtime failed with status \(code)."
        }
    }
}

/// VibeContainers-facing owner for one native virtual phone.
/// The guest lives in its own guest-physical address space; it is not a patched
/// Mach-O launched inside the host process like a LiveContainer guest.
public final class VirtualPhoneSession: @unchecked Sendable {
    public let manifest: VPhoneMachineManifest
    private var runtime: OpaquePointer?

    public init(manifest: VPhoneMachineManifest) throws {
        self.manifest = manifest
        var config = VPMachineConfig(
            cpu_count: manifest.cpuCount,
            guest_physical_memory_size: manifest.guestPhysicalMemorySize,
            screen_width: manifest.screen.width,
            screen_height: manifest.screen.height,
            pixels_per_inch: manifest.screen.pixelsPerInch,
            screen_scale: manifest.screen.scale
        )
        guard let handle = vp_runtime_create(&config) else {
            throw VirtualPhoneSessionError.runtimeCreationFailed
        }
        runtime = handle
    }

    deinit {
        if let runtime { vp_runtime_destroy(runtime) }
    }

    public var committedGuestBytes: UInt64 {
        guard let runtime else { return 0 }
        return vp_runtime_committed_bytes(runtime)
    }

    public func writeGuestPhysicalMemory(address: UInt64, data: Data) throws {
        guard let runtime else { throw VirtualPhoneSessionError.runtimeCreationFailed }
        let status = data.withUnsafeBytes { bytes in
            vp_runtime_memory_write(runtime, address, bytes.baseAddress, bytes.count)
        }
        guard status == VP_STATUS_OK else {
            throw VirtualPhoneSessionError.runtimeFailure(Int32(status.rawValue))
        }
    }

    public func readGuestPhysicalMemory(address: UInt64, count: Int) throws -> Data {
        guard let runtime else { throw VirtualPhoneSessionError.runtimeCreationFailed }
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { bytes in
            vp_runtime_memory_read(runtime, address, bytes.baseAddress, bytes.count)
        }
        guard status == VP_STATUS_OK else {
            throw VirtualPhoneSessionError.runtimeFailure(Int32(status.rawValue))
        }
        return data
    }

    public func boot() throws {
        guard let runtime else { throw VirtualPhoneSessionError.runtimeCreationFailed }
        let status = vp_runtime_boot(runtime)
        if status == VP_STATUS_BACKEND_UNAVAILABLE {
            throw VirtualPhoneSessionError.bootBackendUnavailable
        }
        guard status == VP_STATUS_OK else {
            throw VirtualPhoneSessionError.runtimeFailure(Int32(status.rawValue))
        }
    }

    public func stop() {
        guard let runtime else { return }
        _ = vp_runtime_stop(runtime)
    }
}
