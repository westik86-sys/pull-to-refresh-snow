import SpriteKit
import UIKit

final class SnowScene: SKScene {
    private static let fieldMask: UInt32 = 1 << 0

    private(set) var emissionDuration: TimeInterval
    var totalDuration: TimeInterval {
        emissionDuration + tailDuration
    }

    private var configuration: SnowThemeConfiguration
    private var settings: SnowEffectSettings
    private var tailDuration: TimeInterval {
        let longestParticleLifetime = configuration.layers
            .map { TimeInterval($0.particleLifetime + $0.particleLifetimeRange) }
            .max() ?? 3.4

        return max(3.4, longestParticleLifetime + 0.6)
    }
    private var emitters: [SKEmitterNode] = []
    private var emitterOffsets: [ObjectIdentifier: CGFloat] = [:]
    private var fieldNodes: [SKFieldNode] = []
    private var hasStarted = false
    private var isEmitting = false

    init(
        size: CGSize,
        configuration: SnowThemeConfiguration = .dark,
        settings: SnowEffectSettings = .default
    ) {
        self.configuration = configuration
        self.settings = settings
        emissionDuration = settings.emissionDuration
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        configuration = .dark
        settings = .default
        emissionDuration = settings.emissionDuration
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.allowsTransparency = true
        view.backgroundColor = .clear
    }

    func updateOverlaySize(_ newSize: CGSize) {
        let sanitizedSize = CGSize(
            width: max(newSize.width, 1),
            height: max(newSize.height, 1)
        )

        guard size != sanitizedSize else { return }
        size = sanitizedSize
        repositionSceneNodes()
    }

    func updateConfiguration(_ newConfiguration: SnowThemeConfiguration) {
        guard configuration != newConfiguration else { return }
        configuration = newConfiguration

        guard hasStarted else { return }
        applyCurrentConfiguration()
    }

    func updateSettings(_ newSettings: SnowEffectSettings) {
        guard settings != newSettings else { return }
        settings = newSettings
        emissionDuration = newSettings.emissionDuration
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        isEmitting = true

        removeAllChildren()
        emitters.removeAll()
        emitterOffsets.removeAll()
        fieldNodes.removeAll()

        addTurbulence()
        addEmitters()

        run(
            .sequence([
                .wait(forDuration: emissionDuration),
                .run { [weak self] in
                    self?.stopEmission()
                },
                .wait(forDuration: tailDuration),
                .run { [weak self] in
                    self?.stopAndRemoveAll()
                }
            ]),
            withKey: "snow-lifetime"
        )
    }

    func stopAndRemoveAll() {
        stopEmission()
        removeAction(forKey: "snow-lifetime")
        removeAllChildren()
        emitters.removeAll()
        emitterOffsets.removeAll()
        fieldNodes.removeAll()
        hasStarted = false
        isEmitting = false
    }

    private func configureScene() {
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = .clear
    }

    private func addTurbulence() {
        let turbulence = SKFieldNode.turbulenceField(
            withSmoothness: CGFloat.random(in: configuration.turbulenceSmoothnessRange),
            animationSpeed: CGFloat.random(in: configuration.turbulenceAnimationSpeedRange)
        )
        turbulence.name = "snow-turbulence"
        turbulence.categoryBitMask = Self.fieldMask
        turbulence.strength = Float.random(in: configuration.turbulenceStrengthRange)
        turbulence.falloff = 0
        turbulence.position = CGPoint(x: size.width / 2, y: size.height / 2)

        addChild(turbulence)
        fieldNodes.append(turbulence)
    }

    private func addEmitters() {
        emitters = configuration.layers.map(makeEmitter)

        for emitter in emitters {
            addChild(emitter)
        }

        repositionSceneNodes()
    }

    private func makeEmitter(style: SnowParticleStyle) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        apply(style: style, to: emitter)
        return emitter
    }

    private func applyCurrentConfiguration() {
        for field in fieldNodes {
            field.strength = Float.random(in: configuration.turbulenceStrengthRange)
        }

        guard emitters.count == configuration.layers.count else {
            removeEmitterNodes()
            addEmitters()
            return
        }

        for (emitter, style) in zip(emitters, configuration.layers) {
            apply(style: style, to: emitter)
        }

        repositionSceneNodes()
    }

    private func apply(style: SnowParticleStyle, to emitter: SKEmitterNode) {
        emitter.name = style.name
        emitter.particleTexture = SnowTextureFactory.texture(
            kind: style.textureKind,
            preset: configuration.preset,
            diameter: style.textureDiameter,
            softness: style.textureSoftness
        )
        emitter.particleBirthRate = isEmitting ? style.birthRate : 0
        emitter.particleScale = style.particleScale
        emitter.particleScaleRange = style.particleScaleRange
        emitter.particleScaleSpeed = CGFloat.random(in: style.particleScaleSpeedRange)
        emitter.particleSpeed = style.particleSpeed
        emitter.particleSpeedRange = style.particleSpeedRange
        emitter.particleLifetime = style.particleLifetime
        emitter.particleLifetimeRange = style.particleLifetimeRange
        emitter.particleAlpha = style.particleAlpha
        emitter.particleAlphaRange = style.particleAlphaRange
        emitter.particleAlphaSpeed = 0
        emitter.particleAlphaSequence = makeAlphaSequence(for: style)
        emitter.particleRotation = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
        emitter.particleRotationRange = style.particleRotationRange
        emitter.particleRotationSpeed = CGFloat.random(in: style.particleRotationSpeedRange)
        emitter.emissionAngle = -CGFloat.pi / 2
        emitter.emissionAngleRange = style.emissionAngleRange
        emitter.xAcceleration = CGFloat.random(in: style.xAccelerationRange)
        emitter.yAcceleration = CGFloat.random(in: style.yAccelerationRange)
        emitter.particleBlendMode = style.particleBlendMode
        emitter.particleColor = style.particleColor
        emitter.particleColorBlendFactor = style.particleColorBlendFactor
        emitter.fieldBitMask = Self.fieldMask
        emitter.targetNode = self
        emitterOffsets[ObjectIdentifier(emitter)] = style.offsetY
    }

    private func makeAlphaSequence(for style: SnowParticleStyle) -> SKKeyframeSequence {
        let peakAlpha = NSNumber(value: Double(style.particleAlpha))
        let settledAlpha = NSNumber(value: Double(style.particleAlpha * 0.92))

        let sequence = SKKeyframeSequence(
            keyframeValues: [
                NSNumber(value: 0),
                peakAlpha,
                settledAlpha,
                NSNumber(value: Double(style.particleAlpha * 0.36)),
                NSNumber(value: 0)
            ],
            times: [
                NSNumber(value: 0),
                NSNumber(value: 0.08),
                NSNumber(value: 0.58),
                NSNumber(value: 0.84),
                NSNumber(value: 1)
            ]
        )
        sequence.interpolationMode = .linear
        return sequence
    }

    private func removeEmitterNodes() {
        for emitter in emitters {
            emitter.removeFromParent()
        }
        emitters.removeAll()
        emitterOffsets.removeAll()
    }

    private func stopEmission() {
        isEmitting = false
        for emitter in emitters {
            emitter.particleBirthRate = 0
        }
    }

    private func repositionSceneNodes() {
        for field in fieldNodes {
            field.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }

        for emitter in emitters {
            let offsetY = emitterOffsets[ObjectIdentifier(emitter)] ?? 32
            emitter.position = CGPoint(x: size.width / 2, y: size.height + offsetY)
            emitter.particlePositionRange = CGVector(dx: size.width + 96, dy: 12)
        }
    }
}
