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
}

enum ParticleTextureSource: Hashable {
    case generated(SnowParticleTextureKind)
    case asset(name: String)
    case emoji(String)
    case templateEmoji(String)
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
    func replacingVisuals(
        name: String,
        textureSource: ParticleTextureSource,
        textureDiameter: CGFloat,
        textureSoftness: CGFloat? = nil,
        birthRate: CGFloat? = nil,
        particleScale: CGFloat? = nil,
        particleScaleRange: CGFloat? = nil,
        particleSpeed: CGFloat? = nil,
        particleSpeedRange: CGFloat? = nil,
        particleAlpha: CGFloat? = nil,
        particleAlphaRange: CGFloat? = nil,
        particleRotationSpeedRange: ClosedRange<CGFloat>? = nil,
        particleColor: UIColor? = nil,
        particleColorBlendFactor: CGFloat? = nil
    ) -> SnowParticleStyle {
        SnowParticleStyle(
            name: name,
            textureSource: textureSource,
            textureDiameter: textureDiameter,
            textureSoftness: textureSoftness ?? self.textureSoftness,
            offsetY: offsetY,
            birthRate: birthRate ?? self.birthRate,
            particleScale: particleScale ?? self.particleScale,
            particleScaleRange: particleScaleRange ?? self.particleScaleRange,
            particleScaleSpeedRange: particleScaleSpeedRange,
            particleSpeed: particleSpeed ?? self.particleSpeed,
            particleSpeedRange: particleSpeedRange ?? self.particleSpeedRange,
            particleLifetime: particleLifetime,
            particleLifetimeRange: particleLifetimeRange,
            particleAlpha: particleAlpha ?? self.particleAlpha,
            particleAlphaRange: particleAlphaRange ?? self.particleAlphaRange,
            particleAlphaSpeedRange: particleAlphaSpeedRange,
            particleRotationRange: particleRotationRange,
            particleRotationSpeedRange: particleRotationSpeedRange ?? self.particleRotationSpeedRange,
            emissionAngleRange: emissionAngleRange,
            xAccelerationRange: xAccelerationRange,
            yAccelerationRange: yAccelerationRange,
            particleColor: particleColor ?? self.particleColor,
            particleColorBlendFactor: particleColorBlendFactor ?? self.particleColorBlendFactor,
            particleBlendMode: particleBlendMode
        )
    }

    func applying(_ settings: SnowEffectSettings) -> SnowParticleStyle {
        let density = CGFloat(settings.densityMultiplier)
        let speed = CGFloat(settings.speedMultiplier)
        let scale = CGFloat(settings.scaleMultiplier)
        let alpha = CGFloat(settings.alphaMultiplier)
        let lifetimeScale = CGFloat(max(settings.overlayHeightPercent, 25) / 25)
        let blur = settings.effectKind.usesEmojiInput ? 1 : CGFloat(settings.blurMultiplier)
        let spin = settings.effectKind.usesEmojiInput ? CGFloat(settings.emojiSpin) : 1

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
            particleRotationRange: particleRotationRange * spin,
            particleRotationSpeedRange: (particleRotationSpeedRange.lowerBound * spin)...(particleRotationSpeedRange.upperBound * spin),
            emissionAngleRange: emissionAngleRange,
            xAccelerationRange: (xAccelerationRange.lowerBound * speed)...(xAccelerationRange.upperBound * speed),
            yAccelerationRange: (yAccelerationRange.lowerBound * speed)...(yAccelerationRange.upperBound * speed),
            particleColor: particleColor,
            particleColorBlendFactor: particleColorBlendFactor,
            particleBlendMode: particleBlendMode
        )
    }
}

private struct EmojiLayerTuning {
    let name: String
    let textureDiameter: CGFloat
    let textureSoftness: CGFloat
    let birthRate: CGFloat
    let particleScale: CGFloat
    let particleScaleRange: CGFloat
    let particleSpeed: CGFloat
    let particleSpeedRange: CGFloat
    let particleAlpha: CGFloat
    let particleAlphaRange: CGFloat
    let particleRotationSpeedRange: ClosedRange<CGFloat>
}

private struct EmojiRotationVariant {
    let name: String
    let speedMultiplier: CGFloat
}

private enum EmojiTextureMode {
    case color
    case template
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
        emojiSymbols: [String] = [SnowEffectSettings.defaultEmojiSymbol]
    ) -> SnowThemeConfiguration {
        switch effect {
        case .snow:
            snowConfiguration(for: preset)
        case .emoji:
            emojiConfiguration(for: preset, emojiSymbols: emojiSymbols, textureMode: .color)
        case .emojiTemplate:
            emojiConfiguration(for: preset, emojiSymbols: emojiSymbols, textureMode: .template)
        case .confetti:
            snowConfiguration(for: preset)
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

    private static func emojiConfiguration(
        for preset: SnowVisualPreset,
        emojiSymbols: [String],
        textureMode: EmojiTextureMode
    ) -> SnowThemeConfiguration {
        let baseConfiguration = snowConfiguration(for: preset)
        let symbols = emojiSymbols.isEmpty ? [SnowEffectSettings.defaultEmojiSymbol] : emojiSymbols
        let densityShare = CGFloat(symbols.count)
        let rotationVariants = [
            EmojiRotationVariant(name: "counter-slow", speedMultiplier: -0.36),
            EmojiRotationVariant(name: "clock-slow", speedMultiplier: 0.48),
            EmojiRotationVariant(name: "counter-fast", speedMultiplier: -0.78),
            EmojiRotationVariant(name: "clock-fast", speedMultiplier: 1.0)
        ]
        let layerTunings: [EmojiLayerTuning] = [
            EmojiLayerTuning(
                name: "back-emoji",
                textureDiameter: 44,
                textureSoftness: 0.35,
                birthRate: 22,
                particleScale: 0.24,
                particleScaleRange: 0.14,
                particleSpeed: 60,
                particleSpeedRange: 24,
                particleAlpha: 0.18,
                particleAlphaRange: 0.06,
                particleRotationSpeedRange: -4.0...4.0
            ),
            EmojiLayerTuning(
                name: "mid-emoji",
                textureDiameter: 42,
                textureSoftness: 0.45,
                birthRate: 16,
                particleScale: 0.38,
                particleScaleRange: 0.18,
                particleSpeed: 98,
                particleSpeedRange: 44,
                particleAlpha: 0.48,
                particleAlphaRange: 0.12,
                particleRotationSpeedRange: -6.0...6.0
            ),
            EmojiLayerTuning(
                name: "front-emoji",
                textureDiameter: 52,
                textureSoftness: 0.75,
                birthRate: 3.5,
                particleScale: 0.50,
                particleScaleRange: 0.22,
                particleSpeed: 152,
                particleSpeedRange: 48,
                particleAlpha: 0.32,
                particleAlphaRange: 0.12,
                particleRotationSpeedRange: -5.0...5.0
            )
        ]

        let layers = baseConfiguration.layers.enumerated().flatMap { layerIndex, baseLayer in
            let visualIndex = min(layerIndex, layerTunings.count - 1)
            let tuning = layerTunings[visualIndex]
            let maxRotationSpeed = max(
                abs(tuning.particleRotationSpeedRange.lowerBound),
                abs(tuning.particleRotationSpeedRange.upperBound)
            )

            return symbols.enumerated().flatMap { symbolIndex, emojiSymbol in
                rotationVariants.map { rotationVariant in
                    let rotationSpeed = maxRotationSpeed * rotationVariant.speedMultiplier
                    let textureSource = emojiTextureSource(emojiSymbol, mode: textureMode)

                    return baseLayer.replacingVisuals(
                        name: "\(tuning.name)-\(symbolIndex)-\(rotationVariant.name)",
                        textureSource: textureSource,
                        textureDiameter: tuning.textureDiameter,
                        textureSoftness: tuning.textureSoftness,
                        birthRate: tuning.birthRate / densityShare / CGFloat(rotationVariants.count),
                        particleScale: tuning.particleScale,
                        particleScaleRange: tuning.particleScaleRange,
                        particleSpeed: tuning.particleSpeed,
                        particleSpeedRange: tuning.particleSpeedRange,
                        particleAlpha: tuning.particleAlpha,
                        particleAlphaRange: tuning.particleAlphaRange,
                        particleRotationSpeedRange: rotationSpeed...rotationSpeed,
                        particleColorBlendFactor: 0
                    )
                }
            }
        }

        return baseConfiguration.replacingLayers(layers)
    }

    private static func emojiTextureSource(_ emojiSymbol: String, mode: EmojiTextureMode) -> ParticleTextureSource {
        switch mode {
        case .color:
            .emoji(emojiSymbol)
        case .template:
            .templateEmoji(emojiSymbol)
        }
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

    private func replacingLayers(_ newLayers: [SnowParticleStyle]) -> SnowThemeConfiguration {
        SnowThemeConfiguration(
            preset: preset,
            layers: newLayers,
            turbulenceSmoothnessRange: turbulenceSmoothnessRange,
            turbulenceAnimationSpeedRange: turbulenceAnimationSpeedRange,
            turbulenceStrengthRange: turbulenceStrengthRange
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
            && lhs.particleColor.isEqual(rhs.particleColor)
            && lhs.particleColorBlendFactor == rhs.particleColorBlendFactor
            && lhs.particleBlendMode == rhs.particleBlendMode
    }
}
