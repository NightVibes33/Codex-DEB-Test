import SwiftUI
import HairballUI

// Hairball main moved its effects to iOS 18 TextRenderer APIs. AlleyCat still
// supports iOS 16.1, so the sideload build pins the final iOS 16 renderer and
// maps the newer effect-facing API onto Hairball's TokenAnimator interface.
typealias StreamingTextEffect = TokenAnimator

enum RevealGranularity: Equatable {
    case character
    case chunk(Int)
    case line
    case block
}

extension View {
    func streamingTextEffect(_ effect: any StreamingTextEffect) -> some View {
        tokenAnimator(effect)
    }

    // Per-glyph granularity was introduced with the iOS 18 renderer. The iOS
    // 16 animator still performs continuous token reveal, so preserve the app's
    // configuration surface while treating this modifier as a compatibility no-op.
    func revealGranularity(_ granularity: RevealGranularity) -> some View {
        self
    }
}

protocol LitterLegacyEffectAnimator: TokenAnimator {}

extension LitterLegacyEffectAnimator {
    func animate(
        revealed: AttributedString,
        fresh: AttributedString,
        progress: Double,
        foregroundColor: Color
    ) -> Text {
        var stable = revealed
        stable.foregroundColor = foregroundColor

        var incoming = fresh
        incoming.foregroundColor = foregroundColor.opacity(max(0.08, min(1, progress)))

        if stable.characters.isEmpty { return Text(incoming) }
        if incoming.characters.isEmpty { return Text(stable) }
        return Text(stable) + Text(incoming)
    }
}

struct FadeEdgeEffect: LitterLegacyEffectAnimator {
    let edgeWidth: Int
    init(edgeWidth: Int = 8) { self.edgeWidth = edgeWidth }
}

struct SparkleEffect: LitterLegacyEffectAnimator {
    let sparkleCount: Int
    let color: Color
    init(sparkleCount: Int = 8, color: Color = .yellow) {
        self.sparkleCount = sparkleCount
        self.color = color
    }
}

struct GlowCursorEffect: LitterLegacyEffectAnimator {
    let glowColor: Color
    let glowRadius: CGFloat
    init(glowColor: Color = .cyan, glowRadius: CGFloat = 12) {
        self.glowColor = glowColor
        self.glowRadius = glowRadius
    }
}

struct WaveRevealEffect: LitterLegacyEffectAnimator {
    let amplitude: CGFloat
    let wavelength: CGFloat
    init(amplitude: CGFloat = 6, wavelength: CGFloat = 12) {
        self.amplitude = amplitude
        self.wavelength = wavelength
    }
}

struct ScalePopEffect: LitterLegacyEffectAnimator {
    let popWidth: Int
    init(popWidth: Int = 3) { self.popWidth = popWidth }
}

struct RainbowEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    init(trailLength: Int = 16) { self.trailLength = trailLength }
}

struct FireTrailEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    init(trailLength: Int = 18) { self.trailLength = trailLength }
}

struct ExplosionEffect: LitterLegacyEffectAnimator { init() {} }
struct NyanCatEffect: LitterLegacyEffectAnimator { init() {} }
struct MatrixDecodeEffect: LitterLegacyEffectAnimator { init() {} }
struct PhosphorCRTEffect: LitterLegacyEffectAnimator { init() {} }
struct ShockwaveEffect: LitterLegacyEffectAnimator { init() {} }

struct LitterTypewriterEffect: LitterLegacyEffectAnimator {
    let cursorColor: Color
    init(cursorColor: Color = Color(red: 0, green: 1, blue: 0.612)) {
        self.cursorColor = cursorColor
    }
}

struct LitterTerminalScanEffect: LitterLegacyEffectAnimator {
    let scanColor: Color
    let trailLength: Int
    init(scanColor: Color = Color(red: 0, green: 1, blue: 0.612), trailLength: Int = 18) {
        self.scanColor = scanColor
        self.trailLength = trailLength
    }
}

struct LitterSoftBlurEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    init(trailLength: Int = 12) { self.trailLength = trailLength }
}

struct LitterNeonPulseEffect: LitterLegacyEffectAnimator {
    let color: Color
    let trailLength: Int
    init(color: Color = Color(red: 0, green: 0.95, blue: 1), trailLength: Int = 14) {
        self.color = color
        self.trailLength = trailLength
    }
}

struct LitterGhostTrailEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    let color: Color
    init(trailLength: Int = 16, color: Color = Color(red: 0.68, green: 0.88, blue: 1)) {
        self.trailLength = trailLength
        self.color = color
    }
}

struct LitterPixelDecodeEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    let color: Color
    init(trailLength: Int = 12, color: Color = Color(red: 0.3, green: 0.9, blue: 1)) {
        self.trailLength = trailLength
        self.color = color
    }
}

struct LitterInkSpreadEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    init(trailLength: Int = 10) { self.trailLength = trailLength }
}

struct LitterSlideUpEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    let distance: CGFloat
    init(trailLength: Int = 10, distance: CGFloat = 11) {
        self.trailLength = trailLength
        self.distance = distance
    }
}

struct LitterGlitchEffect: LitterLegacyEffectAnimator {
    let trailLength: Int
    init(trailLength: Int = 12) { self.trailLength = trailLength }
}

struct LitterFocusBeamEffect: LitterLegacyEffectAnimator {
    let color: Color
    let trailLength: Int
    init(color: Color = Color(red: 1, green: 0.95, blue: 0.55), trailLength: Int = 14) {
        self.color = color
        self.trailLength = trailLength
    }
}
