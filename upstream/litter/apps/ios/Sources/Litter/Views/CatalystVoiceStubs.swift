#if targetEnvironment(macCatalyst)
import SwiftUI
import Perception

struct HomeVoiceOrbButton: View {
    let session: VoiceSessionState?
    let isAvailable: Bool
    let isStarting: Bool
    let action: () -> Void

    var body: some View {
        WithPerceptionTracking {
        EmptyView()
    
        }}
}

struct RealtimeVoiceScreen: View {
    let threadKey: ThreadKey
    let onEnd: () -> Void
    let onToggleSpeaker: () -> Void

    var body: some View {
        WithPerceptionTracking {
        EmptyView()
    
        }}
}

struct InlineVoiceButton: View {
    let session: VoiceSessionState?
    let action: () -> Void

    var body: some View {
        WithPerceptionTracking {
        EmptyView()
    
        }}
}
#endif
