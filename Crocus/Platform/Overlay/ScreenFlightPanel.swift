import AppKit
import SwiftUI

/// A transparent, click-through window over a whole screen that exists only
/// while the island flies (C5). Each screen involved gets one; all of them
/// draw the same flight in global coordinates, each the part on its screen.
final class ScreenFlightPanel: NSPanel {
    /// - Parameters:
    ///   - clock: shared by all flight windows; the flight holds its first
    ///     frame until the clock starts.
    ///   - sourceContent: the leaving island's content, dissolving as it detaches.
    ///   - content: the destination island's content, laid out at its final
    ///     size; drawn inside the shape as it lands.
    init(screenFrame: CGRect, flight: ScreenFlight, clock: FlightClock, menuBarIsDark: Bool, sourceContent: AnyView? = nil, content: AnyView? = nil) {
        super.init(contentRect: screenFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        canHide = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: OverlayPanel.overlayLevel.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none

        let view = NSHostingView(rootView: ScreenFlightView(
            flight: flight, clock: clock, screenFrame: screenFrame, menuBarIsDark: menuBarIsDark,
            sourceContent: sourceContent, content: content
        ).islandEnvironment())
        view.sizingOptions = []
        contentView = view
        setFrame(screenFrame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Keep the window over the menu bar where we put it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// The flight's time, shared by its windows. `start` stays `nil` while the
/// windows draw their first frame invisibly; then the flight begins.
@MainActor
final class FlightClock {
    var start: Date?

    func elapsed(at date: Date) -> Double {
        guard let start else { return 0 }
        return max(date.timeIntervalSince(start), 0) / CrocusMotion.slowFactor
    }
}

/// Draws the flying island for one screen, frame by frame.
private struct ScreenFlightView: View {
    let flight: ScreenFlight
    let clock: FlightClock
    let screenFrame: CGRect
    let menuBarIsDark: Bool
    let sourceContent: AnyView?
    let content: AnyView?

    /// Room around the island in its layer for the shoulders and shadow.
    private static let margin: CGFloat = 40

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = min(clock.elapsed(at: context.date), ScreenFlight.duration)
            let frame = flight.frame(at: elapsed)
            let rect = localRect(frame.form.rect)
            let m = Self.margin
            // The island is drawn in a small layer of its own size (plus
            // margin) that moves across the screen – shadow, blur and mask
            // never touch the whole screen, so no frame is dropped.
            island(frame: frame, elapsed: elapsed, in: CGRect(x: m, y: m, width: rect.width, height: rect.height))
                .frame(width: rect.width + 2 * m, height: rect.height + 2 * m)
                // Stretched along its path, around the island's top edge.
                .scaleEffect(x: frame.scaleX, y: frame.scaleY, anchor: UnitPoint(x: 0.5, y: m / (rect.height + 2 * m)))
                .position(x: rect.midX, y: rect.midY)
                .frame(width: screenFrame.width, height: screenFrame.height)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func island(frame: ScreenFlight.Frame, elapsed: Double, in rect: CGRect) -> some View {
        let shape = FlightIslandShape(form: frame.form, rect: rect)
        let outline = ScreenFlight.departureFade(at: elapsed) * ScreenFlight.handoverShadow(at: elapsed)
        let sourceOpacity = ScreenFlight.sourceContentOpacity(at: elapsed)
        let contentIn = ScreenFlight.contentProgress(at: elapsed)

        ZStack(alignment: .topLeading) {
            PillShadow.apply(to: shape.fill(CrocusColors.island))
                .opacity(frame.form.shadow * outline)
            shape.fill(CrocusColors.island)
            if let sourceContent, sourceOpacity > 0 {
                // Shrinks with the leaving shape while it dissolves.
                sourceContent
                    .frame(width: flight.from.rect.width, height: flight.from.rect.height)
                    .scaleEffect(rect.width / max(flight.from.rect.width, 1))
                    .position(x: rect.midX, y: rect.midY)
                    .blur(radius: CGFloat(1 - sourceOpacity) * 4)
                    .opacity(sourceOpacity)
                    .mask { shape }
            }
            if let content, contentIn > 0 {
                // Grows with the arriving shape: sized to its width,
                // sharpening as it docks.
                content
                    .frame(width: flight.to.rect.width, height: flight.to.rect.height)
                    .scaleEffect(rect.width / max(flight.to.rect.width, 1) * (0.92 + 0.08 * contentIn))
                    .position(x: rect.midX, y: rect.midY)
                    .blur(radius: (1 - contentIn) * 4)
                    .opacity(Double(contentIn))
                    .mask { shape }
            }
            shape.stroke(PillOutline.color(menuBarIsDark: menuBarIsDark), lineWidth: PillOutline.width)
                .opacity(frame.form.shadow * outline)
        }
    }

    /// Global screen coordinates (y up) → this window (top-left origin).
    private func localRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - screenFrame.minX, y: screenFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// The flying island's outline: rounded at the bottom; at the top either
/// hanging from the edge with concave shoulders (notch) or rounded too
/// (in flight, pill).
struct FlightIslandShape: Shape {
    let form: FlightForm
    /// The island in the shape's coordinates (top-left origin).
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        let y0 = rect.minY
        let half = min(rect.width, rect.height) / 2
        let bottom = min(max(form.bottomRadius, 0), half)
        let shoulder = max(form.shoulderRadius, 0)
        if shoulder > 0.01 {
            // Hanging from the top edge: exactly the notch island's outline,
            // so taking over from it (and handing back) shows no seam.
            let parameters = NotchShapeParameters(
                leading: rect.width / 2, trailing: rect.width / 2, height: rect.height,
                bottomRadius: bottom, shoulderRadius: shoulder
            )
            return NotchIslandShape(parameters: parameters, centerX: rect.midX)
                .path(in: CGRect(x: 0, y: y0, width: 0, height: 0))
        }

        let top = min(max(form.topRadius, 0), half)
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerRadii: RectangleCornerRadii(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top),
            style: .continuous
        )
        return path
    }
}
