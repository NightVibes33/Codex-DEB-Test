import Foundation
import Observation

private enum VKStopReason: Int32 {
    case none = 0
    case wfi = 1
    case svc = 2
    case illegalInstruction = 3
    case memoryFault = 4
    case instructionLimit = 5
}

@_silgen_name("vk_runtime_create")
private func vk_runtime_create(_ memorySize: Int) -> UnsafeMutableRawPointer?

@_silgen_name("vk_runtime_destroy")
private func vk_runtime_destroy(_ runtime: UnsafeMutableRawPointer?)

@_silgen_name("vk_runtime_load")
private func vk_runtime_load(
    _ runtime: UnsafeMutableRawPointer?,
    _ bytes: UnsafeRawPointer?,
    _ size: Int,
    _ guestAddress: UInt64
) -> Int32

@_silgen_name("vk_runtime_reset")
private func vk_runtime_reset(
    _ runtime: UnsafeMutableRawPointer?,
    _ pc: UInt64,
    _ sp: UInt64
) -> Int32

@_silgen_name("vk_runtime_run")
private func vk_runtime_run(
    _ runtime: UnsafeMutableRawPointer?,
    _ instructionLimit: UInt64
) -> Int32

@_silgen_name("vk_runtime_instruction_count")
private func vk_runtime_instruction_count(_ runtime: UnsafeMutableRawPointer?) -> UInt64

@_silgen_name("vk_runtime_build_marker")
private func vk_runtime_build_marker() -> UnsafePointer<CChar>?

@Observable
@MainActor
final class VPhoneRuntimeEngine {
    enum State: Equatable {
        case stopped
        case ready(memoryBytes: Int)
        case running
        case trapped(reason: String, instructions: UInt64)
        case failed(String)
    }

    static let shared = VPhoneRuntimeEngine()

    private(set) var state: State = .stopped
    private var runtime: UnsafeMutableRawPointer?

    var buildMarker: String {
        guard let ptr = vk_runtime_build_marker() else { return "VIBEKERNEL-UNKNOWN" }
        return String(cString: ptr)
    }

    private init() {}

    deinit {
        if let runtime { vk_runtime_destroy(runtime) }
    }

    func prepare(memoryBytes: Int = 64 * 1024 * 1024) {
        shutdown()
        guard let created = vk_runtime_create(memoryBytes) else {
            state = .failed("Could not allocate VibeKernel guest memory.")
            return
        }
        runtime = created
        state = .ready(memoryBytes: memoryBytes)
    }

    func shutdown() {
        if let runtime { vk_runtime_destroy(runtime) }
        runtime = nil
        state = .stopped
    }

    /// Loads a raw guest image at a guest-physical address. M0 deliberately
    /// accepts bytes only; Mach-O/kernelcache parsing and boot manifests land in M2.
    func loadRawImage(_ data: Data, guestAddress: UInt64 = 0) throws {
        guard let runtime else {
            throw RuntimeError.notPrepared
        }
        let result = data.withUnsafeBytes { rawBuffer in
            vk_runtime_load(runtime, rawBuffer.baseAddress, rawBuffer.count, guestAddress)
        }
        guard result == 0 else { throw RuntimeError.imageDoesNotFit }
    }

    func boot(entryPoint: UInt64, stackPointer: UInt64, instructionLimit: UInt64 = 1_000_000) {
        guard let runtime else {
            state = .failed("Runtime is not prepared.")
            return
        }
        guard vk_runtime_reset(runtime, entryPoint, stackPointer) == 0 else {
            state = .failed("Invalid entry point or stack pointer.")
            return
        }

        state = .running
        let reason = VKStopReason(rawValue: vk_runtime_run(runtime, instructionLimit))
        let count = vk_runtime_instruction_count(runtime)
        switch reason {
        case .some(.wfi):
            state = .trapped(reason: "WFI", instructions: count)
        case .some(.svc):
            state = .trapped(reason: "SVC", instructions: count)
        case .some(.illegalInstruction):
            state = .trapped(reason: "Illegal instruction", instructions: count)
        case .some(.memoryFault):
            state = .trapped(reason: "Memory fault", instructions: count)
        case .some(.instructionLimit):
            state = .trapped(reason: "Instruction limit", instructions: count)
        case .some(.none), .none:
            state = .trapped(reason: "Stopped", instructions: count)
        }
    }

    enum RuntimeError: LocalizedError {
        case notPrepared
        case imageDoesNotFit

        var errorDescription: String? {
            switch self {
            case .notPrepared:
                return "Prepare VibeKernel before loading a guest image."
            case .imageDoesNotFit:
                return "The guest image does not fit in the configured guest memory."
            }
        }
    }
}

@_cdecl("VPhoneRuntimeBuildMarker")
func VPhoneRuntimeBuildMarker() -> UnsafePointer<CChar>? {
    vk_runtime_build_marker()
}
