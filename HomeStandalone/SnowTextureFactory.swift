import SpriteKit
import UIKit

enum SnowTextureFactory {
    private static let textureCache = SnowTextureCache()
    private static let lightFillColor = UIColor(red: 214 / 255, green: 231 / 255, blue: 238 / 255, alpha: 1)
    private static let lightCoreColor = UIColor(red: 234 / 255, green: 244 / 255, blue: 248 / 255, alpha: 1)
    private static let lightStrokeColor = UIColor(red: 144 / 255, green: 178 / 255, blue: 192 / 255, alpha: 0.72)
    private static let lightEdgeColor = UIColor(red: 108 / 255, green: 142 / 255, blue: 156 / 255, alpha: 0.30)
    private static let lightGlowColor = UIColor(red: 188 / 255, green: 221 / 255, blue: 234 / 255, alpha: 1)

    private struct FrostBlob {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let alpha: CGFloat
    }

    static func texture(
        source: ParticleTextureSource,
        preset: SnowVisualPreset,
        diameter: CGFloat,
        softness: CGFloat = 1
    ) -> SKTexture {
        let softnessStep: Int
        let cachedSoftness: CGFloat

        switch source {
        case .generated:
            let normalizedSoftness = min(max(softness, 0), 2)
            softnessStep = Int((normalizedSoftness * 20).rounded())
            cachedSoftness = CGFloat(softnessStep) / 20
        case .asset(_), .emoji(_):
            softnessStep = 0
            cachedSoftness = 0
        }

        let key = SnowTextureCache.Key(
            source: source,
            preset: preset,
            diameter: diameter,
            softnessStep: softnessStep
        )
        if let cachedTexture = textureCache.texture(for: key) {
            return cachedTexture
        }

        let texture: SKTexture
        switch source {
        case .generated(let kind):
            texture = makeTexture(
                diameter: diameter,
                variant: Variant(kind: kind),
                preset: preset,
                softness: cachedSoftness
            )
        case .asset(let assetName):
            texture = makeAssetTexture(named: assetName, diameter: diameter)
        case .emoji(let emoji):
            texture = makeEmojiTexture(emoji, diameter: diameter)
        }
        textureCache.store(texture, for: key)
        return texture
    }

    static func texture(
        kind: SnowParticleTextureKind,
        preset: SnowVisualPreset,
        diameter: CGFloat,
        softness: CGFloat = 1
    ) -> SKTexture {
        texture(
            source: .generated(kind),
            preset: preset,
            diameter: diameter,
            softness: softness
        )
    }

    static func softDotTexture(diameter: CGFloat) -> SKTexture {
        texture(kind: .softDot, preset: .dark, diameter: diameter)
    }

    static func crystalTexture(diameter: CGFloat) -> SKTexture {
        texture(kind: .crystal, preset: .dark, diameter: diameter)
    }

    static func softFlakeTexture(diameter: CGFloat) -> SKTexture {
        texture(kind: .softFlake, preset: .dark, diameter: diameter)
    }

    private enum Variant {
        case softDot
        case crystal
        case softFlake
        case iceSpark
        case frostSpeck
        case frostDot
        case frostBlur
        case leaf

        init(kind: SnowParticleTextureKind) {
            switch kind {
            case .softDot:
                self = .softDot
            case .crystal:
                self = .crystal
            case .softFlake:
                self = .softFlake
            case .iceSpark:
                self = .iceSpark
            case .frostSpeck:
                self = .frostSpeck
            case .frostDot:
                self = .frostDot
            case .frostBlur:
                self = .frostBlur
            case .leaf:
                self = .leaf
            }
        }
    }

    private static func makeTexture(
        diameter: CGFloat,
        variant: Variant,
        preset: SnowVisualPreset,
        softness: CGFloat
    ) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat()
        let displayScale = UITraitCollection.current.displayScale
        format.scale = displayScale > 0 ? displayScale : 2
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(origin: .zero, size: size)

            drawGlow(
                in: rect,
                context: context,
                preset: preset,
                centerAlpha: glowAlpha(for: variant, preset: preset),
                softness: softness
            )

            switch variant {
            case .softDot:
                drawSoftDot(in: rect, context: context, preset: preset)
            case .crystal:
                drawCrystal(in: rect, context: context, preset: preset)
            case .softFlake:
                drawSoftFlake(in: rect, context: context, preset: preset)
            case .iceSpark:
                drawIceSpark(in: rect, context: context)
            case .frostSpeck:
                drawFrostSpeck(in: rect, context: context, preset: preset, softness: softness)
            case .frostDot:
                drawFrostDot(in: rect, context: context, preset: preset, softness: softness)
            case .frostBlur:
                drawFrostBlur(in: rect, context: context, preset: preset, softness: softness)
            case .leaf:
                drawLeaf(in: rect, context: context, preset: preset)
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func makeAssetTexture(named assetName: String, diameter: CGFloat) -> SKTexture {
        guard let assetImage = UIImage(named: assetName) else {
            assertionFailure("Missing particle texture asset named \(assetName)")
            return makeMissingAssetTexture(diameter: diameter)
        }

        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat()
        let displayScale = UITraitCollection.current.displayScale
        format.scale = displayScale > 0 ? displayScale : 2
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            assetImage.draw(in: aspectFitRect(for: assetImage.size, in: CGRect(origin: .zero, size: size)))
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func makeMissingAssetTexture(diameter: CGFloat) -> SKTexture {
        makeTexture(
            diameter: diameter,
            variant: .softDot,
            preset: .dark,
            softness: 0
        )
    }

    private static func makeEmojiTexture(_ emoji: String, diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat()
        let displayScale = UITraitCollection.current.displayScale
        format.scale = displayScale > 0 ? displayScale : 2
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let text = NSString(string: emoji)
            let maxTextSize = CGSize(width: diameter * 0.92, height: diameter * 0.92)
            var fontSize = diameter * 0.74
            var attributes = emojiAttributes(fontSize: fontSize)
            var textSize = text.size(withAttributes: attributes)

            while (textSize.width > maxTextSize.width || textSize.height > maxTextSize.height)
                && fontSize > diameter * 0.22 {
                fontSize *= 0.92
                attributes = emojiAttributes(fontSize: fontSize)
                textSize = text.size(withAttributes: attributes)
            }

            text.draw(
                at: CGPoint(
                    x: (diameter - textSize.width) / 2,
                    y: (diameter - textSize.height) / 2
                ),
                withAttributes: attributes
            )
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func emojiAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
    }

    private static func aspectFitRect(for sourceSize: CGSize, in rect: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return rect }

        let scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
        let fittedSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        return CGRect(
            x: rect.midX - fittedSize.width / 2,
            y: rect.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private static func glowAlpha(for variant: Variant, preset: SnowVisualPreset) -> CGFloat {
        switch (variant, preset) {
        case (.softDot, .dark):
            0.85
        case (.frostBlur, .dark):
            0.18
        case (.frostSpeck, .dark):
            0.0
        case (.frostDot, .dark):
            0.12
        case (.leaf, .dark):
            0.0
        case (_, .dark):
            0.36
        case (.softFlake, .light):
            0.30
        case (.iceSpark, .light):
            0.24
        case (.frostBlur, .light):
            0.18
        case (.frostSpeck, .light):
            0.0
        case (.frostDot, .light):
            0.12
        case (.leaf, .light):
            0.0
        case (_, .light):
            0.28
        }
    }

    private static func drawGlow(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset,
        centerAlpha: CGFloat,
        softness: CGFloat
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let glowColor: UIColor

        switch preset {
        case .dark:
            glowColor = .white
        case .light:
            glowColor = lightGlowColor
        }

        let effectiveAlpha = centerAlpha * (0.78 + softness * 0.22)
        let colors = [
            glowColor.withAlphaComponent(effectiveAlpha).cgColor,
            glowColor.withAlphaComponent(0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 1]

        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        ) else {
            return
        }

        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: rect.width / 2 * (1 + softness * 0.16),
            options: [.drawsAfterEndLocation]
        )
    }

    private static func drawSoftDot(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset
    ) {
        let inset = rect.width * 0.26
        let dotRect = rect.insetBy(dx: inset, dy: inset)

        if preset == .light {
            context.setShadow(
                offset: .zero,
                blur: rect.width * 0.12,
                color: lightEdgeColor.cgColor
            )
            context.setStrokeColor(lightStrokeColor.withAlphaComponent(0.50).cgColor)
            context.setLineWidth(max(0.8, rect.width * 0.075))
            context.strokeEllipse(in: dotRect.insetBy(dx: -rect.width * 0.04, dy: -rect.height * 0.04))
        }

        let fillColor = preset == .light
            ? lightFillColor.withAlphaComponent(0.92)
            : UIColor.white.withAlphaComponent(0.78)
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: dotRect)
        context.setShadow(offset: .zero, blur: 0)
    }

    private static func drawCrystal(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.36
        let branchLength = radius * 0.38
        let strokeColor: UIColor
        let edgeColor: UIColor
        let shadowColor: UIColor

        switch preset {
        case .dark:
            strokeColor = UIColor.white.withAlphaComponent(0.9)
            edgeColor = UIColor.white.withAlphaComponent(0)
            shadowColor = UIColor.white.withAlphaComponent(0.45)
        case .light:
            strokeColor = lightCoreColor.withAlphaComponent(0.96)
            edgeColor = lightStrokeColor
            shadowColor = lightEdgeColor
        }

        if preset == .light {
            context.setShadow(
                offset: .zero,
                blur: rect.width * 0.12,
                color: shadowColor.cgColor
            )
            strokeCrystal(
                in: rect,
                context: context,
                color: edgeColor,
                lineWidth: max(1.2, rect.width * 0.12),
                radius: radius,
                branchLength: branchLength
            )
            context.setShadow(offset: .zero, blur: 0)
        }

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(max(1, rect.width * 0.055))
        context.setLineCap(.round)
        context.setShadow(
            offset: .zero,
            blur: rect.width * (preset == .light ? 0.08 : 0.05),
            color: (preset == .light ? lightGlowColor.withAlphaComponent(0.24) : shadowColor).cgColor
        )

        strokeCrystal(
            in: rect,
            context: context,
            color: strokeColor,
            lineWidth: max(1, rect.width * (preset == .light ? 0.062 : 0.055)),
            radius: radius,
            branchLength: branchLength
        )

        context.setShadow(offset: .zero, blur: 0)
        let centerFillColor = preset == .light
            ? lightCoreColor.withAlphaComponent(0.98)
            : UIColor.white.withAlphaComponent(0.95)
        context.setFillColor(centerFillColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - rect.width * 0.08,
            y: center.y - rect.width * 0.08,
            width: rect.width * 0.16,
            height: rect.width * 0.16
        ))
    }

    private static func strokeCrystal(
        in rect: CGRect,
        context: CGContext,
        color: UIColor,
        lineWidth: CGFloat,
        radius: CGFloat,
        branchLength: CGFloat
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)

        for index in 0..<6 {
            let angle = CGFloat(index) * CGFloat.pi / 3
            let end = point(from: center, radius: radius, angle: angle)

            context.move(to: center)
            context.addLine(to: end)
            context.strokePath()

            let branchBase = point(from: center, radius: radius * 0.62, angle: angle)
            let branchAngle = CGFloat.pi / 5
            let left = point(from: branchBase, radius: branchLength, angle: angle + CGFloat.pi - branchAngle)
            let right = point(from: branchBase, radius: branchLength, angle: angle + CGFloat.pi + branchAngle)

            context.move(to: branchBase)
            context.addLine(to: left)
            context.strokePath()

            context.move(to: branchBase)
            context.addLine(to: right)
            context.strokePath()
        }
    }

    private static func drawSoftFlake(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()
        let points = 8

        for index in 0..<points {
            let angle = CGFloat(index) * 2 * CGFloat.pi / CGFloat(points)
            let radiusMultiplier: CGFloat = index.isMultiple(of: 2) ? 0.34 : 0.24
            let point = point(from: center, radius: rect.width * radiusMultiplier, angle: angle)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()

        if preset == .light {
            context.setShadow(
                offset: .zero,
                blur: rect.width * 0.12,
                color: lightEdgeColor.cgColor
            )
            context.setStrokeColor(lightStrokeColor.withAlphaComponent(0.52).cgColor)
            context.setLineWidth(max(0.9, rect.width * 0.07))
            context.addPath(path.cgPath)
            context.strokePath()
        }

        let flakeFillColor = preset == .light
            ? lightFillColor.withAlphaComponent(0.88)
            : UIColor.white.withAlphaComponent(0.72)
        context.setFillColor(flakeFillColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        context.setShadow(offset: .zero, blur: 0)
        let flakeCoreColor = preset == .light
            ? lightCoreColor.withAlphaComponent(0.76)
            : UIColor.white.withAlphaComponent(0.55)
        context.setFillColor(flakeCoreColor.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: rect.width * 0.34, dy: rect.height * 0.34))
    }

    private static func drawIceSpark(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let longRadius = rect.width * 0.34
        let shortRadius = rect.width * 0.17
        let path = UIBezierPath()

        for index in 0..<8 {
            let angle = CGFloat(index) * CGFloat.pi / 4
            let radius = index.isMultiple(of: 2) ? longRadius : shortRadius
            let point = point(from: center, radius: radius, angle: angle)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()

        context.setShadow(
            offset: .zero,
            blur: rect.width * 0.10,
            color: lightEdgeColor.cgColor
        )
        context.setStrokeColor(lightStrokeColor.withAlphaComponent(0.52).cgColor)
        context.setLineWidth(max(0.7, rect.width * 0.06))
        context.addPath(path.cgPath)
        context.strokePath()

        context.setShadow(offset: .zero, blur: 0)
        context.setFillColor(lightFillColor.withAlphaComponent(0.88).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    }

    private static func drawLeaf(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: center.x, y: rect.minY + rect.height * 0.12)
        let bottom = CGPoint(x: center.x, y: rect.maxY - rect.height * 0.12)
        let leafPath = UIBezierPath()

        leafPath.move(to: top)
        leafPath.addCurve(
            to: bottom,
            controlPoint1: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.28),
            controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.09, y: rect.maxY - rect.height * 0.12)
        )
        leafPath.addCurve(
            to: top,
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.10),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.30)
        )
        leafPath.close()

        let fillStartColor: UIColor
        let fillEndColor: UIColor
        let strokeColor: UIColor
        let veinColor: UIColor
        let shadowColor: UIColor

        switch preset {
        case .dark:
            fillStartColor = UIColor(red: 174 / 255, green: 190 / 255, blue: 87 / 255, alpha: 0.92)
            fillEndColor = UIColor(red: 104 / 255, green: 140 / 255, blue: 61 / 255, alpha: 0.92)
            strokeColor = UIColor(red: 75 / 255, green: 102 / 255, blue: 46 / 255, alpha: 0.58)
            veinColor = UIColor(red: 235 / 255, green: 216 / 255, blue: 143 / 255, alpha: 0.42)
            shadowColor = UIColor.black.withAlphaComponent(0.18)
        case .light:
            fillStartColor = UIColor(red: 156 / 255, green: 176 / 255, blue: 78 / 255, alpha: 0.90)
            fillEndColor = UIColor(red: 83 / 255, green: 122 / 255, blue: 55 / 255, alpha: 0.90)
            strokeColor = UIColor(red: 52 / 255, green: 86 / 255, blue: 43 / 255, alpha: 0.50)
            veinColor = UIColor(red: 244 / 255, green: 223 / 255, blue: 146 / 255, alpha: 0.40)
            shadowColor = UIColor.black.withAlphaComponent(0.12)
        }

        context.saveGState()
        context.setShadow(offset: .zero, blur: rect.width * 0.10, color: shadowColor.cgColor)
        context.setFillColor(strokeColor.withAlphaComponent(0.34).cgColor)
        context.addPath(leafPath.cgPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(leafPath.cgPath)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            fillStartColor.cgColor,
            fillEndColor.cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 1]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY),
                end: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY),
                options: []
            )
        }
        context.restoreGState()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(max(0.7, rect.width * 0.04))
        context.addPath(leafPath.cgPath)
        context.strokePath()

        context.setStrokeColor(veinColor.cgColor)
        context.setLineWidth(max(0.5, rect.width * 0.026))
        context.setLineCap(.round)
        context.move(to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.17))
        context.addCurve(
            to: CGPoint(x: center.x, y: rect.maxY - rect.height * 0.18),
            control1: CGPoint(x: center.x + rect.width * 0.05, y: rect.minY + rect.height * 0.36),
            control2: CGPoint(x: center.x - rect.width * 0.04, y: rect.maxY - rect.height * 0.34)
        )
        context.strokePath()

        let veinOffsets: [CGFloat] = [0.38, 0.52, 0.66]

        for offset in veinOffsets {
            let y = rect.minY + rect.height * offset
            let veinLength = rect.width * (0.13 + (offset - 0.38) * 0.10)

            context.move(to: CGPoint(x: center.x, y: y))
            context.addLine(to: CGPoint(x: center.x + veinLength, y: y - rect.height * 0.075))
            context.strokePath()

            context.move(to: CGPoint(x: center.x, y: y + rect.height * 0.02))
            context.addLine(to: CGPoint(x: center.x - veinLength * 0.82, y: y + rect.height * 0.095))
            context.strokePath()
        }
    }

    private static func drawFrostSpeck(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset,
        softness: CGFloat
    ) {
        drawFrostClump(
            in: rect,
            context: context,
            preset: preset,
            softness: softness,
            blobs: [
                FrostBlob(x: 0.48, y: 0.46, radius: 0.16, alpha: 0.70),
                FrostBlob(x: 0.57, y: 0.53, radius: 0.10, alpha: 0.54)
            ],
            edgeAlpha: 0.22,
            shadowAlpha: 0.10,
            shadowBlur: 0.04,
            fillScale: 0.78
        )
    }

    private static func drawFrostDot(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset,
        softness: CGFloat
    ) {
        drawFrostClump(
            in: rect,
            context: context,
            preset: preset,
            softness: softness,
            blobs: [
                FrostBlob(x: 0.43, y: 0.48, radius: 0.17, alpha: 0.76),
                FrostBlob(x: 0.55, y: 0.43, radius: 0.15, alpha: 0.70),
                FrostBlob(x: 0.56, y: 0.58, radius: 0.12, alpha: 0.58),
                FrostBlob(x: 0.37, y: 0.58, radius: 0.09, alpha: 0.48)
            ],
            edgeAlpha: 0.34,
            shadowAlpha: 0.16,
            shadowBlur: 0.08,
            fillScale: 0.72
        )
    }

    private static func drawFrostBlur(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset,
        softness: CGFloat
    ) {
        drawFrostClump(
            in: rect,
            context: context,
            preset: preset,
            softness: softness,
            blobs: [
                FrostBlob(x: 0.42, y: 0.46, radius: 0.18, alpha: 0.52),
                FrostBlob(x: 0.55, y: 0.43, radius: 0.21, alpha: 0.58),
                FrostBlob(x: 0.61, y: 0.58, radius: 0.15, alpha: 0.42),
                FrostBlob(x: 0.37, y: 0.61, radius: 0.12, alpha: 0.36),
                FrostBlob(x: 0.51, y: 0.60, radius: 0.17, alpha: 0.44)
            ],
            edgeAlpha: 0.18,
            shadowAlpha: 0.22,
            shadowBlur: 0.16,
            fillScale: 0.82
        )
    }

    private static func drawFrostClump(
        in rect: CGRect,
        context: CGContext,
        preset: SnowVisualPreset,
        softness: CGFloat,
        blobs: [FrostBlob],
        edgeAlpha: CGFloat,
        shadowAlpha: CGFloat,
        shadowBlur: CGFloat,
        fillScale: CGFloat
    ) {
        let edgeColor: UIColor
        let shadowColor: UIColor
        let fillColor: UIColor

        switch preset {
        case .dark:
            edgeColor = .white
            shadowColor = .white
            fillColor = .white
        case .light:
            edgeColor = lightStrokeColor
            shadowColor = lightEdgeColor
            fillColor = lightFillColor
        }

        context.setShadow(
            offset: .zero,
            blur: rect.width * shadowBlur * (0.75 + softness * 0.55),
            color: shadowColor.withAlphaComponent(shadowAlpha * (0.8 + softness * 0.28)).cgColor
        )

        for blob in blobs {
            let blobRect = clumpRect(in: rect, blob: blob, scale: 1.08 + softness * 0.08)
            context.setFillColor(edgeColor.withAlphaComponent(edgeAlpha * blob.alpha * (0.9 + softness * 0.16)).cgColor)
            context.fillEllipse(in: blobRect)
        }

        context.setShadow(offset: .zero, blur: 0)

        for blob in blobs {
            let blobRect = clumpRect(in: rect, blob: blob, scale: fillScale + softness * 0.035)
            context.setFillColor(fillColor.withAlphaComponent(blob.alpha * (1 - softness * 0.06)).cgColor)
            context.fillEllipse(in: blobRect)
        }
    }

    private static func clumpRect(in rect: CGRect, blob: FrostBlob, scale: CGFloat) -> CGRect {
        let radius = rect.width * blob.radius * scale
        let center = CGPoint(
            x: rect.minX + rect.width * blob.x,
            y: rect.minY + rect.height * blob.y
        )

        return CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    private static func point(from center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

private final class SnowTextureCache: @unchecked Sendable {
    struct Key: Hashable {
        let source: ParticleTextureSource
        let preset: SnowVisualPreset
        let diameter: CGFloat
        let softnessStep: Int
    }

    private var textures: [Key: SKTexture] = [:]
    private let lock = NSLock()

    func texture(for key: Key) -> SKTexture? {
        lock.lock()
        defer { lock.unlock() }
        return textures[key]
    }

    func store(_ texture: SKTexture, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        textures[key] = texture
    }
}
