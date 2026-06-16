import SpriteKit
import SwiftUI

struct SnowOverlay: View {
    let triggerID: UUID?
    let settings: SnowEffectSettings
    let onFinished: () -> Void

    @State private var scene = SnowScene(size: CGSize(width: 1, height: 1))
    @State private var activeTriggerID: UUID?
    @State private var finishWorkItem: DispatchWorkItem?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene, options: [.allowsTransparency])
                .background(Color.clear)
                .accessibilityHidden(true)
            .compositingGroup()
            .mask(bottomFadeMask)
            .onAppear {
                prepareScene(size: proxy.size)
                startIfNeeded(triggerID: triggerID, size: proxy.size)
            }
            .onChange(of: proxy.size) { _, newSize in
                scene.updateOverlaySize(newSize)
            }
            .onChange(of: triggerID) { _, newTriggerID in
                startIfNeeded(triggerID: newTriggerID, size: proxy.size)
            }
            .onChange(of: colorScheme) { _, _ in
                scene.updateConfiguration(currentConfiguration)
            }
            .onChange(of: settings) { _, newSettings in
                scene.updateSettings(newSettings)
                scene.updateConfiguration(currentConfiguration)
            }
            .onDisappear {
                finishWorkItem?.cancel()
                finishWorkItem = nil
                scene.stopAndRemoveAll()
            }
        }
        .allowsHitTesting(false)
    }

    private func prepareScene(size: CGSize) {
        scene.updateOverlaySize(size)
        scene.updateSettings(settings)
        scene.updateConfiguration(currentConfiguration)
    }

    private func startIfNeeded(triggerID: UUID?, size: CGSize) {
        guard let triggerID, triggerID != activeTriggerID else { return }

        finishWorkItem?.cancel()
        finishWorkItem = nil
        activeTriggerID = triggerID

        scene.stopAndRemoveAll()
        prepareScene(size: size)

        scene.start()

        let workItem = DispatchWorkItem {
            scene.stopAndRemoveAll()
            activeTriggerID = nil
            finishWorkItem = nil
            onFinished()
        }
        finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + scene.totalDuration + 0.05,
            execute: workItem
        )
    }

    private var currentConfiguration: SnowThemeConfiguration {
        SnowThemeConfiguration
            .configuration(for: colorScheme == .dark ? .dark : .light)
            .applying(settings)
    }

    private var bottomFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.58),
                .init(color: .black.opacity(0.72), location: 0.74),
                .init(color: .black.opacity(0.28), location: 0.9),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
