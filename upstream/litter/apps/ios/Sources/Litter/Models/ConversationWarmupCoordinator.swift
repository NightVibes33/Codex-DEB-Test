import Foundation
import Perception
@MainActor
@Perceptible
final class ConversationWarmupCoordinator {
    private(set) var activeWarmupID: UUID?
    private(set) var hasCompletedWarmup = false

    @PerceptionIgnored private var isPrewarming = false
    @PerceptionIgnored private var pendingContinuations: [CheckedContinuation<Void, Never>] = []

    func prewarmIfNeeded() async {
        guard !hasCompletedWarmup else { return }

        if isPrewarming {
            await withCheckedContinuation { continuation in
                pendingContinuations.append(continuation)
            }
            return
        }

        isPrewarming = true
        activeWarmupID = UUID()

        await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    func finishWarmup() {
        guard isPrewarming else { return }

        hasCompletedWarmup = true
        isPrewarming = false
        activeWarmupID = nil

        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
