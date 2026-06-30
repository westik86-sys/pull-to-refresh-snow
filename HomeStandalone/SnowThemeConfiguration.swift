import SpriteKit
import UIKit

enum SnowVisualPreset: Equatable {
    case dark
    case light
}

enum SnowParticleTextureKind: Hashable {
    case softDot
    case crystal
    case softFlake
    case iceSpark
    case frostSpeck
    case frostDot
    case frostBlur
    case leaf
}

enum ParticleTextureSource: Hashable {
    case generated(SnowParticleTextureKind)
    case asset(name: String)
    case emoji(String)
}

struct SnowParticleStyle {
    let name: String
    let textureSource: ParticleTextureSource
    let textureDiameter: CGFloat
    let textureSoftness: CGFloat
    let offsetY: CGFloat
    let birthRate: CGFloat
    let particleScale: CGFloat
    let particleScaleRange: CGFloat
    let particleScaleSpeedRange: ClosedRange<CGFloat>
    let particleSpeed: CGFloat
    let particleSpeedRange: CGFloat
    let particleLifetime: CGFloat
    let particleLifetimeRange: CGFloat
    let particleAlpha: CGFloat
    let particleAlphaRange: CGFloat
    let particleAlphaSpeedRange: ClosedRange<CGFloat>
    let particleRotationRange: CGFloat
    let particleRotationSpeedRange: ClosedRange<CGFloat>
    let emissionAngleRange: CGFloat
    let xAccelerationRange: ClosedRange<CGFloat>
    let yAccelerationRange: ClosedRange<CGFloat>
    let particleColor: UIColor
    let particleColorBlendFactor: CGFloat
    let particleBlendMode: SKBlendMode
}

extension SnowParticleStyle {
    func applying(_ settings: SnowEffectSettings) -> SnowParticleStyle {
        let density = CGFloat(settings.densityMultiplier)
        let speed = CGFloat(settings.speedMultiplier)
        let scale = CGFloat(settings.scaleMultiplier)
        let alpha = CGFloat(settings.alphaMultiplier)
        let lifetimeScale = CGFloat(max(settings.overlayHeightPercent, 25) / 25)
        let blur = CGFloat(settings.blurMultiplier)

        return SnowParticleStyle(
            name: name,
            textureSource: textureSource,
            textureDiameter: textureDiameter,
            textureSoftness: textureSoftness * blur,
            offsetY: offsetY,
            birthRate: birthRate * density,
            particleScale: particleScale * scale,
            particleScaleRange: particleScaleRange * scale,
            particleScaleSpeedRange: (particleScaleSpeedRange.lowerBound * scale)...(particleScaleSpeedRange.upperBound * scale),
            particleSpeed: particleSpeed * speed,
            particleSpeedRange: particleSpeedRange * speed,
            particleLifetime: particleLifetime * lifetimeScale,
            particleLifetimeRange: particleLifetimeRange * lifetimeScale,
            particleAlpha: min(max(particleAlpha * alpha, 0.05), 1.0),
            particleAlphaRange: min(max(particleAlphaRange * alpha, 0), 1.0),
            particleAlphaSpeedRange: particleAlphaSpeedRange,
            particleRotationRange: particleRotationRange,
            particleRotationSpeedRange: particleRotationSpeedRange,
            emissionAngleRange: emissionAngleRange,
            xAccelerationRange: (xAccelerationRange.lowerBound * speed)...(xAccelerationRange.upperBound * speed),
            yAccelerationRange: (yAccelerationRange.lowerBound * speed)...(yAccelerationRange.upperBound * speed),
            particleColor: particleColor,
            particleColorBlendFactor: particleColorBlendFactor,
            particleBlendMode: particleBlendMode
        )
    }
}

struct SnowThemeConfiguration: Equatable {
    let preset: SnowVisualPreset
    let layers: [SnowParticleStyle]
    let turbulenceSmoothnessRange: ClosedRange<CGFloat>
    let turbulenceAnimationSpeedRange: ClosedRange<CGFloat>
    let turbulenceStrengthRange: ClosedRange<Float>

    static let dark = SnowThemeConfiguration(
        preset: .dark,
        layers: [
            SnowParticleStyle(
                name: "back-frost-specks",
                textureSource: .generated(.frostSpeck),
                textureDiameter: 8,
                textureSoftness: 1.25,
                offsetY: 24,
                birthRate: 58,
                particleScale: 0.14,
                particleScaleRange: 0.09,
                particleScaleSpeedRange: -0.035...0.0,
                particleSpeed: 62,
                particleSpeedRange: 28,
                particleLifetime: 2.75,
                particleLifetimeRange: 1.1,
                particleAlpha: 0.34,
                particleAlphaRange: 0.18,
                particleAlphaSpeedRange: -0.10...(-0.025),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -1.2...1.2,
                emissionAngleRange: CGFloat.pi / 7,
                xAccelerationRange: -8...12,
                yAccelerationRange: -16...(-6),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            ),
            SnowParticleStyle(
                name: "mid-soft-frost-dots",
                textureSource: .generated(.frostDot),
                textureDiameter: 18,
                textureSoftness: 0.75,
                offsetY: 40,
                birthRate: 18,
                particleScale: 0.40,
                particleScaleRange: 0.24,
                particleScaleSpeedRange: -0.035...0.0,
                particleSpeed: 118,
                particleSpeedRange: 44,
                particleLifetime: 2.15,
                particleLifetimeRange: 0.85,
                particleAlpha: 0.52,
                particleAlphaRange: 0.18,
                particleAlphaSpeedRange: -0.15...(-0.04),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -1.2...1.2,
                emissionAngleRange: CGFloat.pi / 5,
                xAccelerationRange: -18...22,
                yAccelerationRange: -26...(-12),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            ),
            SnowParticleStyle(
                name: "front-defocused-frost",
                textureSource: .generated(.frostBlur),
                textureDiameter: 36,
                textureSoftness: 1.55,
                offsetY: 52,
                birthRate: 4.0,
                particleScale: 0.476,
                particleScaleRange: 0.168,
                particleScaleSpeedRange: -0.025...0.0,
                particleSpeed: 184,
                particleSpeedRange: 56,
                particleLifetime: 1.7,
                particleLifetimeRange: 0.55,
                particleAlpha: 0.46,
                particleAlphaRange: 0.16,
                particleAlphaSpeedRange: -0.18...(-0.06),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -0.45...0.45,
                emissionAngleRange: CGFloat.pi / 4,
                xAccelerationRange: -20...24,
                yAccelerationRange: -48...(-26),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            )
        ],
        turbulenceSmoothnessRange: 0.52...0.78,
        turbulenceAnimationSpeedRange: 0.14...0.28,
        turbulenceStrengthRange: 0.14...0.28
    )

    static let light = SnowThemeConfiguration(
        preset: .light,
        layers: [
            SnowParticleStyle(
                name: "back-frost-specks",
                textureSource: .generated(.frostSpeck),
                textureDiameter: 8,
                textureSoftness: 1.25,
                offsetY: 24,
                birthRate: 58,
                particleScale: 0.14,
                particleScaleRange: 0.09,
                particleScaleSpeedRange: -0.035...0.0,
                particleSpeed: 62,
                particleSpeedRange: 28,
                particleLifetime: 2.75,
                particleLifetimeRange: 1.1,
                particleAlpha: 0.34,
                particleAlphaRange: 0.18,
                particleAlphaSpeedRange: -0.10...(-0.025),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -1.2...1.2,
                emissionAngleRange: CGFloat.pi / 7,
                xAccelerationRange: -8...12,
                yAccelerationRange: -16...(-6),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            ),
            SnowParticleStyle(
                name: "mid-soft-frost-dots",
                textureSource: .generated(.frostDot),
                textureDiameter: 18,
                textureSoftness: 0.75,
                offsetY: 40,
                birthRate: 18,
                particleScale: 0.40,
                particleScaleRange: 0.24,
                particleScaleSpeedRange: -0.035...0.0,
                particleSpeed: 118,
                particleSpeedRange: 44,
                particleLifetime: 2.15,
                particleLifetimeRange: 0.85,
                particleAlpha: 0.52,
                particleAlphaRange: 0.18,
                particleAlphaSpeedRange: -0.15...(-0.04),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -1.2...1.2,
                emissionAngleRange: CGFloat.pi / 5,
                xAccelerationRange: -18...22,
                yAccelerationRange: -26...(-12),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            ),
            SnowParticleStyle(
                name: "front-defocused-frost",
                textureSource: .generated(.frostBlur),
                textureDiameter: 36,
                textureSoftness: 1.55,
                offsetY: 52,
                birthRate: 4.0,
                particleScale: 0.476,
                particleScaleRange: 0.168,
                particleScaleSpeedRange: -0.025...0.0,
                particleSpeed: 184,
                particleSpeedRange: 56,
                particleLifetime: 1.7,
                particleLifetimeRange: 0.55,
                particleAlpha: 0.46,
                particleAlphaRange: 0.16,
                particleAlphaSpeedRange: -0.18...(-0.06),
                particleRotationRange: CGFloat.pi * 2,
                particleRotationSpeedRange: -0.45...0.45,
                emissionAngleRange: CGFloat.pi / 4,
                xAccelerationRange: -20...24,
                yAccelerationRange: -48...(-26),
                particleColor: .white,
                particleColorBlendFactor: 0,
                particleBlendMode: .alpha
            )
        ],
        turbulenceSmoothnessRange: 0.52...0.78,
        turbulenceAnimationSpeedRange: 0.14...0.28,
        turbulenceStrengthRange: 0.14...0.28
    )

    static func configuration(
        for preset: SnowVisualPreset,
        effect: PullRefreshEffectKind = .snow,
        emojiSymbol: String = SnowEffectSettings.defaultEmojiSymbol
    ) -> SnowThemeConfiguration {
        switch effect {
        case .snow:
            snowConfiguration(for: preset)
        case .leaves:
            leavesConfiguration(for: preset)
        case .emoji:
            emojiConfiguration(for: preset, emojiSymbol: emojiSymbol)
        }
    }

    private static func snowConfiguration(for preset: SnowVisualPreset) -> SnowThemeConfiguration {
        switch preset {
        case .dark:
            dark
        case .light:
            light
        }
    }

    private static func leavesConfiguration(for preset: SnowVisualPreset) -> SnowThemeConfiguration {
        let backColor: UIColor
        let midColor: UIColor
        let frontColor: UIColor

        switch preset {
        case .dark:
            backColor = UIColor(red: 95 / 255, green: 134 / 255, blue: 66 / 255, alpha: 1)
            midColor = UIColor(red: 148 / 255, green: 174 / 255, blue: 79 / 255, alpha: 1)
            frontColor = UIColor(red: 192 / 255, green: 151 / 255, blue: 63 / 255, alpha: 1)
        case .light:
            backColor = UIColor(red: 73 / 255, green: 112 / 255, blue: 54 / 255, alpha: 1)
            midColor = UIColor(red: 124 / 255, green: 151 / 255, blue: 67 / 255, alpha: 1)
            frontColor = UIColor(red: 174 / 255, green: 124 / 255, blue: 49 / 255, alpha: 1)
        }

        return SnowThemeConfiguration(
            preset: preset,
            layers: [
                SnowParticleStyle(
                    name: "back-small-leaves",
                    textureSource: .generated(.leaf),
                    textureDiameter: 28,
                    textureSoftness: 0.15,
                    offsetY: 26,
                    birthRate: 8,
                    particleScale: 0.34,
                    particleScaleRange: 0.16,
                    particleScaleSpeedRange: -0.018...0.006,
                    particleSpeed: 42,
                    particleSpeedRange: 24,
                    particleLifetime: 3.3,
                    particleLifetimeRange: 1.2,
                    particleAlpha: 0.58,
                    particleAlphaRange: 0.16,
                    particleAlphaSpeedRange: -0.08...(-0.02),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -2.4...2.4,
                    emissionAngleRange: CGFloat.pi / 3,
                    xAccelerationRange: -32...36,
                    yAccelerationRange: -10...(-4),
                    particleColor: backColor,
                    particleColorBlendFactor: 0.42,
                    particleBlendMode: .alpha
                ),
                SnowParticleStyle(
                    name: "mid-drifting-leaves",
                    textureSource: .generated(.leaf),
                    textureDiameter: 34,
                    textureSoftness: 0.08,
                    offsetY: 42,
                    birthRate: 6,
                    particleScale: 0.48,
                    particleScaleRange: 0.22,
                    particleScaleSpeedRange: -0.014...0.008,
                    particleSpeed: 58,
                    particleSpeedRange: 32,
                    particleLifetime: 2.8,
                    particleLifetimeRange: 0.9,
                    particleAlpha: 0.72,
                    particleAlphaRange: 0.16,
                    particleAlphaSpeedRange: -0.10...(-0.03),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -3.2...3.2,
                    emissionAngleRange: CGFloat.pi / 2.7,
                    xAccelerationRange: -42...46,
                    yAccelerationRange: -14...(-6),
                    particleColor: midColor,
                    particleColorBlendFactor: 0.36,
                    particleBlendMode: .alpha
                ),
                SnowParticleStyle(
                    name: "front-large-leaves",
                    textureSource: .generated(.leaf),
                    textureDiameter: 42,
                    textureSoftness: 0,
                    offsetY: 56,
                    birthRate: 2.8,
                    particleScale: 0.58,
                    particleScaleRange: 0.24,
                    particleScaleSpeedRange: -0.012...0.006,
                    particleSpeed: 74,
                    particleSpeedRange: 36,
                    particleLifetime: 2.35,
                    particleLifetimeRange: 0.8,
                    particleAlpha: 0.80,
                    particleAlphaRange: 0.14,
                    particleAlphaSpeedRange: -0.12...(-0.04),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -3.8...3.8,
                    emissionAngleRange: CGFloat.pi / 2.5,
                    xAccelerationRange: -50...54,
                    yAccelerationRange: -18...(-8),
                    particleColor: frontColor,
                    particleColorBlendFactor: 0.30,
                    particleBlendMode: .alpha
                )
            ],
            turbulenceSmoothnessRange: 0.42...0.70,
            turbulenceAnimationSpeedRange: 0.18...0.34,
            turbulenceStrengthRange: 0.20...0.38
        )
    }

    private static func emojiConfiguration(
        for preset: SnowVisualPreset,
        emojiSymbol: String
    ) -> SnowThemeConfiguration {
        SnowThemeConfiguration(
            preset: preset,
            layers: [
                SnowParticleStyle(
                    name: "back-emoji",
                    textureSource: .emoji(emojiSymbol),
                    textureDiameter: 30,
                    textureSoftness: 0,
                    offsetY: 28,
                    birthRate: 7,
                    particleScale: 0.34,
                    particleScaleRange: 0.16,
                    particleScaleSpeedRange: -0.012...0.006,
                    particleSpeed: 46,
                    particleSpeedRange: 22,
                    particleLifetime: 3.0,
                    particleLifetimeRange: 1.0,
                    particleAlpha: 0.62,
                    particleAlphaRange: 0.14,
                    particleAlphaSpeedRange: -0.08...(-0.02),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -2.0...2.0,
                    emissionAngleRange: CGFloat.pi / 3.2,
                    xAccelerationRange: -28...32,
                    yAccelerationRange: -10...(-4),
                    particleColor: .white,
                    particleColorBlendFactor: 0,
                    particleBlendMode: .alpha
                ),
                SnowParticleStyle(
                    name: "mid-emoji",
                    textureSource: .emoji(emojiSymbol),
                    textureDiameter: 38,
                    textureSoftness: 0,
                    offsetY: 44,
                    birthRate: 5,
                    particleScale: 0.46,
                    particleScaleRange: 0.20,
                    particleScaleSpeedRange: -0.010...0.006,
                    particleSpeed: 62,
                    particleSpeedRange: 30,
                    particleLifetime: 2.55,
                    particleLifetimeRange: 0.8,
                    particleAlpha: 0.78,
                    particleAlphaRange: 0.12,
                    particleAlphaSpeedRange: -0.10...(-0.03),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -2.8...2.8,
                    emissionAngleRange: CGFloat.pi / 2.8,
                    xAccelerationRange: -40...44,
                    yAccelerationRange: -15...(-6),
                    particleColor: .white,
                    particleColorBlendFactor: 0,
                    particleBlendMode: .alpha
                ),
                SnowParticleStyle(
                    name: "front-emoji",
                    textureSource: .emoji(emojiSymbol),
                    textureDiameter: 46,
                    textureSoftness: 0,
                    offsetY: 58,
                    birthRate: 2.8,
                    particleScale: 0.56,
                    particleScaleRange: 0.22,
                    particleScaleSpeedRange: -0.010...0.006,
                    particleSpeed: 78,
                    particleSpeedRange: 34,
                    particleLifetime: 2.1,
                    particleLifetimeRange: 0.65,
                    particleAlpha: 0.86,
                    particleAlphaRange: 0.10,
                    particleAlphaSpeedRange: -0.12...(-0.04),
                    particleRotationRange: CGFloat.pi * 2,
                    particleRotationSpeedRange: -3.4...3.4,
                    emissionAngleRange: CGFloat.pi / 2.6,
                    xAccelerationRange: -48...52,
                    yAccelerationRange: -18...(-8),
                    particleColor: .white,
                    particleColorBlendFactor: 0,
                    particleBlendMode: .alpha
                )
            ],
            turbulenceSmoothnessRange: 0.42...0.70,
            turbulenceAnimationSpeedRange: 0.18...0.34,
            turbulenceStrengthRange: 0.18...0.34
        )
    }

    func applying(_ settings: SnowEffectSettings) -> SnowThemeConfiguration {
        let turbulence = Float(settings.turbulenceMultiplier)
        return SnowThemeConfiguration(
            preset: preset,
            layers: layers.map { $0.applying(settings) },
            turbulenceSmoothnessRange: turbulenceSmoothnessRange,
            turbulenceAnimationSpeedRange: turbulenceAnimationSpeedRange,
            turbulenceStrengthRange: (turbulenceStrengthRange.lowerBound * turbulence)...(turbulenceStrengthRange.upperBound * turbulence)
        )
    }
}

extension SnowParticleStyle: Equatable {
    static func == (lhs: SnowParticleStyle, rhs: SnowParticleStyle) -> Bool {
        lhs.name == rhs.name
            && lhs.textureSource == rhs.textureSource
            && lhs.textureDiameter == rhs.textureDiameter
            && lhs.textureSoftness == rhs.textureSoftness
            && lhs.offsetY == rhs.offsetY
            && lhs.birthRate == rhs.birthRate
            && lhs.particleScale == rhs.particleScale
            && lhs.particleScaleRange == rhs.particleScaleRange
            && lhs.particleScaleSpeedRange == rhs.particleScaleSpeedRange
            && lhs.particleSpeed == rhs.particleSpeed
            && lhs.particleSpeedRange == rhs.particleSpeedRange
            && lhs.particleLifetime == rhs.particleLifetime
            && lhs.particleLifetimeRange == rhs.particleLifetimeRange
            && lhs.particleAlpha == rhs.particleAlpha
            && lhs.particleAlphaRange == rhs.particleAlphaRange
            && lhs.particleAlphaSpeedRange == rhs.particleAlphaSpeedRange
            && lhs.particleRotationRange == rhs.particleRotationRange
            && lhs.particleRotationSpeedRange == rhs.particleRotationSpeedRange
            && lhs.emissionAngleRange == rhs.emissionAngleRange
            && lhs.xAccelerationRange == rhs.xAccelerationRange
            && lhs.yAccelerationRange == rhs.yAccelerationRange
            && lhs.particleColorBlendFactor == rhs.particleColorBlendFactor
            && lhs.particleBlendMode == rhs.particleBlendMode
    }
}
