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

struct SnowParticleStyle {
    let name: String
    let textureKind: SnowParticleTextureKind
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
            textureKind: textureKind,
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
                textureKind: .frostSpeck,
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
                textureKind: .frostDot,
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
                textureKind: .frostBlur,
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
                textureKind: .frostSpeck,
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
                textureKind: .frostDot,
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
                textureKind: .frostBlur,
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

    static func configuration(for preset: SnowVisualPreset) -> SnowThemeConfiguration {
        switch preset {
        case .dark:
            dark
        case .light:
            light
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
}

extension SnowParticleStyle: Equatable {
    static func == (lhs: SnowParticleStyle, rhs: SnowParticleStyle) -> Bool {
        lhs.name == rhs.name
            && lhs.textureKind == rhs.textureKind
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
