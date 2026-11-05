import AppKit

/// Snapshot of one connected screen.
struct ScreenDescriptor: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let geometry: ScreenGeometry

    var frame: CGRect { geometry.frame }

    /// Whether a point in screen coordinates lies on this screen. The top edge
    /// counts (the pointer can rest at `maxY`), the right edge doesn't, so
    /// neighbouring screens never both match.
    func contains(_ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x < frame.maxX && point.y > frame.minY && point.y <= frame.maxY
    }

    static func screen(containing point: CGPoint, in screens: [ScreenDescriptor]) -> CGDirectDisplayID? {
        screens.first { $0.contains(point) }?.displayID
    }
}

extension ScreenDescriptor {
    /// All connected screens, in `NSScreen.screens` order (the first one is
    /// the main display chosen in Displays › Arrange).
    @MainActor
    static func current() -> [ScreenDescriptor] {
        NSScreen.screens.compactMap(ScreenDescriptor.init(screen:))
    }

    @MainActor
    init?(screen: NSScreen) {
        guard let displayID = screen.displayID else { return nil }
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        self.init(
            displayID: displayID,
            name: screen.localizedName,
            isBuiltIn: isBuiltIn,
            geometry: .make(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxLeft: screen.auxiliaryTopLeftArea,
                auxRight: screen.auxiliaryTopRightArea,
                isBuiltIn: isBuiltIn
            )
        )
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
