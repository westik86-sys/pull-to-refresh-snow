import SwiftUI

struct ConfettiOverlay: View {
    let triggerID: UUID?
    let settings: SnowEffectSettings
    let onFinished: () -> Void

    @State private var activeTriggerID: UUID?
    @State private var startDate: Date?
    @State private var finishWorkItem: DispatchWorkItem?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard let startDate else { return }

                let elapsed = max(0, timeline.date.timeIntervalSince(startDate))
                guard elapsed <= totalDuration else { return }

                drawConfetti(elapsed: elapsed, size: size, context: &context)
            }
        }
        .accessibilityHidden(true)
        .compositingGroup()
        .mask(bottomFadeMask)
        .onAppear {
            startIfNeeded(triggerID: triggerID)
        }
        .onChange(of: triggerID) { _, newTriggerID in
            startIfNeeded(triggerID: newTriggerID)
        }
        .onDisappear {
            finishWorkItem?.cancel()
            finishWorkItem = nil
            activeTriggerID = nil
            startDate = nil
        }
    }

    private var tailDuration: TimeInterval {
        max(1.4, 2.8 / max(settings.speedMultiplier, 0.2))
    }

    private var totalDuration: TimeInterval {
        settings.emissionDuration + tailDuration
    }

    private func startIfNeeded(triggerID: UUID?) {
        guard let triggerID, triggerID != activeTriggerID else { return }

        finishWorkItem?.cancel()
        activeTriggerID = triggerID
        startDate = Date()

        let workItem = DispatchWorkItem {
            startDate = nil
            activeTriggerID = nil
            finishWorkItem = nil
            onFinished()
        }
        finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + totalDuration + 0.05,
            execute: workItem
        )
    }

    private func drawConfetti(
        elapsed: TimeInterval,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        let density = CGFloat(settings.densityMultiplier)
        let speed = CGFloat(settings.speedMultiplier)
        let scale = CGFloat(settings.scaleMultiplier)
        let alpha = CGFloat(settings.alphaMultiplier)
        let turbulence = CGFloat(settings.turbulenceMultiplier)
        let sparkle = CGFloat(settings.blurMultiplier)

        drawInitialBurst(
            elapsed: elapsed,
            density: density,
            speed: speed,
            scale: scale,
            alpha: alpha,
            turbulence: turbulence,
            sparkle: sparkle,
            size: size,
            context: &context
        )

        let pieceCount = max(24, Int((54 + density * 86).rounded()))
        let emissionDuration = CGFloat(max(settings.emissionDuration, 0.1))

        for index in 0..<pieceCount {
            let seed = Double(index + 1)
            let delay = confettiHash(seed * 7.9) * emissionDuration
            let lifetime = (1.55 + confettiHash(seed * 5.7) * 1.75) / max(speed, 0.2)
            let age = CGFloat(elapsed) - delay
            guard age >= 0, age <= lifetime else { continue }

            let progress = age / max(lifetime, 0.001)
            let depth = confettiHash(seed * 3.1)
            let easedFall = pow(progress, 0.78)
            let baseX = confettiHash(seed * 11.3) * size.width
            let sway = sin(progress * .pi * 2 * (1 + confettiHash(seed * 13.1) * 2.4) + CGFloat(seed)) * size.width * 0.045
            let windOffset = (turbulence - 0.8) * size.width * (progress - 0.18) * (0.08 + depth * 0.12)
            let x = baseX + sway + windOffset
            let y = -size.height * 0.18 + easedFall * size.height * 1.32
            let fadeIn = min(progress / 0.08, 1)
            let fadeOut = min((1 - progress) / 0.16, 1)
            let pieceAlpha = min(fadeIn, fadeOut) * (0.44 + depth * 0.56) * min(max(alpha, 0), 1.4)
            let rotation = CGFloat(elapsed) * speed * (2.2 + confettiHash(seed * 23.5) * 8.0) + CGFloat(seed)

            renderConfettiPiece(
                index: index,
                seed: seed,
                position: CGPoint(x: x, y: y),
                rotation: rotation,
                depth: depth,
                alpha: pieceAlpha,
                scale: scale,
                sparkle: sparkle,
                context: &context
            )
        }
    }

    private func drawInitialBurst(
        elapsed: TimeInterval,
        density: CGFloat,
        speed: CGFloat,
        scale: CGFloat,
        alpha: CGFloat,
        turbulence: CGFloat,
        sparkle: CGFloat,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        let duration = max(1.2, 2.25 / max(speed, 0.2))
        let age = CGFloat(elapsed)
        guard age <= duration else { return }

        let pieceCount = max(14, Int((28 + density * 24).rounded()))
        let origin = CGPoint(x: size.width * 0.5, y: -size.height * 0.08)
        let minDimension = max(min(size.width, size.height), 1)

        for index in 0..<pieceCount {
            let seed = Double(index + 1) * 17.371
            let spread = CGFloat.pi * (0.72 + confettiHash(seed * 19.1) * 0.42)
            let angle = CGFloat.pi / 2 + (confettiHash(seed * 23.5) - 0.5) * spread
            let depth = confettiHash(seed * 3.1)
            let velocity = minDimension * (0.42 + density * 0.18) * speed * (0.78 + confettiHash(seed * 5.7) * 0.72)
            let gravity = size.height * (0.28 + speed * 0.16)
            let drift = (turbulence - 0.8) * size.width * age * (0.05 + depth * 0.08)
            let flutter = sin(age * (3.4 + confettiHash(seed * 7.9) * 6.4) + CGFloat(seed)) * minDimension * 0.032 * (1 + turbulence * 0.32)
            let x = origin.x + cos(angle) * velocity * age + drift + flutter
            let y = origin.y + sin(angle) * velocity * age + 0.5 * gravity * age * age
            let fadeIn = min(age / 0.1, 1)
            let fadeOut = min((duration - age) / 0.7, 1)
            let pieceAlpha = min(fadeIn, fadeOut) * (0.56 + depth * 0.44) * min(max(alpha, 0), 1.4)
            let rotation = CGFloat(elapsed) * speed * (4.0 + confettiHash(seed * 11.3) * 11.0) + CGFloat(seed)

            renderConfettiPiece(
                index: index,
                seed: seed,
                position: CGPoint(x: x, y: y),
                rotation: rotation,
                depth: depth,
                alpha: pieceAlpha,
                scale: scale * 1.08,
                sparkle: sparkle,
                context: &context
            )
        }
    }

    private func renderConfettiPiece(
        index: Int,
        seed: Double,
        position: CGPoint,
        rotation: CGFloat,
        depth: CGFloat,
        alpha: CGFloat,
        scale: CGFloat,
        sparkle: CGFloat,
        context: inout GraphicsContext
    ) {
        guard alpha > 0.01 else { return }

        let baseLength = (7 + confettiHash(seed * 17.3) * 15) * scale * (0.76 + depth * 0.7)
        let baseWidth = baseLength * (0.34 + confettiHash(seed * 19.1) * 0.5)
        let flip = 0.32 + abs(sin(rotation * 0.9 + CGFloat(seed))) * 0.78
        let shine = sparkle > 0 ? 0.48 + 0.52 * abs(sin(rotation * 1.7)) : 1
        let color = confettiColor(seed: seed).opacity(Double(alpha * shine))

        var pieceContext = context
        pieceContext.translateBy(x: position.x, y: position.y)
        pieceContext.rotate(by: .radians(Double(rotation)))
        pieceContext.scaleBy(x: flip, y: 1)

        let shape = index % 5
        renderPaperConfetti(
            shape: shape,
            baseLength: baseLength,
            baseWidth: baseWidth,
            color: color,
            context: &pieceContext
        )

        if sparkle > 0.05 && shape != 3 && shine > 0.88 {
            renderGlint(
                baseLength: baseLength,
                baseWidth: baseWidth,
                alpha: alpha * min(sparkle, 1.4),
                context: &pieceContext
            )
        }
    }

    private func renderPaperConfetti(
        shape: Int,
        baseLength: CGFloat,
        baseWidth: CGFloat,
        color: Color,
        context: inout GraphicsContext
    ) {
        switch shape {
        case 0:
            var path = Path()
            path.addRoundedRect(
                in: CGRect(x: -baseWidth / 2, y: -baseLength / 2, width: baseWidth, height: baseLength),
                cornerSize: CGSize(width: baseWidth * 0.35, height: baseWidth * 0.35)
            )
            context.fill(path, with: .color(color))
        case 1:
            var path = Path()
            path.move(to: CGPoint(x: 0, y: -baseLength * 0.52))
            path.addLine(to: CGPoint(x: baseWidth * 0.62, y: baseLength * 0.42))
            path.addLine(to: CGPoint(x: -baseWidth * 0.62, y: baseLength * 0.42))
            path.closeSubpath()
            context.fill(path, with: .color(color))
        case 2:
            let circleRect = CGRect(x: -baseWidth / 2, y: -baseWidth / 2, width: baseWidth, height: baseWidth)
            context.fill(Path(ellipseIn: circleRect), with: .color(color))
        case 3:
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -baseLength * 0.48, y: 0))
            ribbon.addCurve(
                to: CGPoint(x: baseLength * 0.48, y: 0),
                control1: CGPoint(x: -baseLength * 0.12, y: -baseWidth),
                control2: CGPoint(x: baseLength * 0.12, y: baseWidth)
            )
            context.stroke(
                ribbon,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.4, baseWidth * 0.32), lineCap: .round)
            )
        default:
            var path = Path()
            path.move(to: CGPoint(x: -baseWidth * 0.56, y: -baseLength * 0.38))
            path.addLine(to: CGPoint(x: baseWidth * 0.56, y: -baseLength * 0.5))
            path.addLine(to: CGPoint(x: baseWidth * 0.44, y: baseLength * 0.38))
            path.addLine(to: CGPoint(x: -baseWidth * 0.44, y: baseLength * 0.5))
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
    }

    private func renderGlint(
        baseLength: CGFloat,
        baseWidth: CGFloat,
        alpha: CGFloat,
        context: inout GraphicsContext
    ) {
        let glintRect = CGRect(
            x: -baseWidth * 0.16,
            y: -baseLength * 0.38,
            width: max(1, baseWidth * 0.3),
            height: max(1, baseWidth * 0.3)
        )
        context.fill(Path(ellipseIn: glintRect), with: .color(.white.opacity(Double(alpha * 0.42))))
    }

    private func confettiColor(seed: Double) -> Color {
        let hue = Double(confettiHash(seed * 29.7))
        let saturation = Double(0.66 + confettiHash(seed * 31.5) * 0.28)
        let brightness = Double(0.78 + confettiHash(seed * 37.1) * 0.2)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func confettiHash(_ value: Double) -> CGFloat {
        let raw = sin(value * 12.9898) * 43_758.5453
        return CGFloat(raw - floor(raw))
    }

    private var bottomFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.56),
                .init(color: .black.opacity(0.74), location: 0.74),
                .init(color: .black.opacity(0.28), location: 0.9),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
