import SwiftUI

/// The welcome page's island: the real notch island in a loop – idle →
/// music → timer → build, 1.2 s each – on a small dark "screen". It has its
/// own store with sample activities and takes no input.
struct IslandDemoView: View {
    @State private var demo = IslandDemo()

    var body: some View {
        let panel = OverlayLayout.panelSize
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.20), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
            NotchIslandView(model: demo.model)
                .frame(width: panel.width, height: panel.height)
                .scaleEffect(IslandDemo.scale, anchor: .top)
                .frame(width: 280, height: 104, alignment: .top)
        }
        .frame(width: 280, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .allowsHitTesting(false)
        .islandEnvironment()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The island shows music, a timer and a build in turn")
        .task { await demo.run() }
    }
}

@MainActor
@Observable
final class IslandDemo {
    static let scale: CGFloat = 0.62
    static let stepDuration: Duration = .milliseconds(1200)

    /// A MacBook-sized screen with a 186 pt notch.
    static let geometry = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        mode: .notch,
        notchRect: CGRect(x: 663, y: 950, width: 186, height: 32),
        menuBarHeight: 32
    )

    let store: IslandStore
    let model: OverlayPanelModel

    init() {
        store = IslandStore(defaults: UserDefaults(suiteName: "com.rbatmaz69.crocus.demo") ?? .standard)
        model = OverlayPanelModel(geometry: Self.geometry, store: store)
    }

    /// Loops until the page goes away.
    func run() async {
        let steps: [SampleActivity?] = [nil, SampleActivities.music, SampleActivities.timer, SampleActivities.liveActivity]
        var current: SampleActivity?
        var index = 0
        while !Task.isCancelled {
            let next = steps[index % steps.count]
            // Add before removing: compact → compact, never through idle.
            if let next { store.upsert(next) }
            if let current, current.id != next?.id { store.remove(id: current.id) }
            current = next
            model.presentation = store.presentation
            index += 1
            try? await Task.sleep(for: Self.stepDuration)
        }
        if let current { store.remove(id: current.id) }
    }
}
