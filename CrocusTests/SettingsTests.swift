import AppKit
import Carbon.HIToolbox
import Testing
@testable import Crocus

@Suite struct SettingsTests {
    @Test func draggingReordersOnlyTheMovableKinds() {
        let priority = ActivityPriority.default
        let first = priority.movable[0]
        // Drag the first movable row to the end.
        let moved = priority.moving(fromOffsets: [0], toOffset: priority.movable.count)
        #expect(moved.movable.last == first)
        #expect(moved.order.first == .cameraMicrophone)
        // And back to the top.
        let back = moved.moving(fromOffsets: [moved.movable.count - 1], toOffset: 0)
        #expect(back == priority)
    }

    @Test func movingDownByOneRow() {
        let priority = ActivityPriority.default
        let (a, b) = (priority.movable[0], priority.movable[1])
        let moved = priority.moving(fromOffsets: [0], toOffset: 2)
        #expect(Array(moved.movable.prefix(2)) == [b, a])
    }

    @Test func strengthSliderHasThreeStops() {
        #expect(MotionStrength(sliderValue: 0) == .subtle)
        #expect(MotionStrength(sliderValue: 1) == .standard)
        #expect(MotionStrength(sliderValue: 2) == .lively)
        for strength in MotionStrength.allCases {
            #expect(MotionStrength(sliderValue: strength.sliderValue) == strength)
        }
    }

    @Test func recordsAShortcutOnlyWithAModifier() {
        let space = UInt16(kVK_Space)
        #expect(KeyboardShortcutSpec(keyCode: space, modifierFlags: [.control, .option]) == .default)
        #expect(KeyboardShortcutSpec(keyCode: space, modifierFlags: []) == nil)
        #expect(KeyboardShortcutSpec(keyCode: UInt16(kVK_ANSI_K), modifierFlags: [.command, .shift])?.displayString == "⇧⌘K")
    }

    @Test func textSizesStayReadableInTheCompactIsland() {
        let title = CrocusTypography.title
        #expect(title.size(for: .large) == 17)
        #expect(title.size(for: .compact) == 14)
        #expect(CrocusTypography.status.size(for: .compact, inCompactIsland: true) == 13)
        #expect(TextSizeAdjustment(rawValue: "large") == .large)
    }
}
