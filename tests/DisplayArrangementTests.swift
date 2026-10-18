// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Chlcony

import Foundation

/// Contract for saved display arrangements. Everything here is the pure half:
/// what counts as the same layout, which preset the live displays match, and
/// what survives a round trip through the preference.
enum DisplayArrangementTests {
    private static let laptop = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
    private static let dell = "4C2E1A61-0000-0000-0000-000000000001"
    private static let missing = "9F000000-0000-0000-0000-0000000000FF"

    private static func slot(_ key: String, _ x: Int, _ y: Int,
                             _ width: Int = 1512, _ height: Int = 982,
                             name: String = "Display") -> DisplaySlot {
        DisplaySlot(key: key, name: name, x: x, y: y, width: width, height: height)
    }

    /// Built-in at the origin with the DELL to its right.
    private static var sideBySide: [DisplaySlot] {
        [slot(laptop, 0, 0, name: "Built-in Retina Display"),
         slot(dell, 1512, 0, 2560, 1440, name: "DELL S2722DC")]
    }

    /// The DELL owns the menu bar and the laptop sits underneath it.
    private static var stacked: [DisplaySlot] {
        [slot(dell, 0, 0, 2560, 1440, name: "DELL S2722DC"),
         slot(laptop, 524, 1440, name: "Built-in Retina Display")]
    }

    static func run(_ suite: TestSuite) {
        identity(suite)
        matching(suite)
        geometry(suite)
        mainDisplay(suite)
        storage(suite)
    }

    private static func identity(_ suite: TestSuite) {
        suite.expect(DisplayArrangementSupport.sameLayout(sideBySide, sideBySide.reversed()),
                     "the order the system lists displays in does not change the layout")
        suite.expect(!DisplayArrangementSupport.sameLayout(sideBySide, stacked),
                     "side by side and stacked are different layouts")

        // A monitor renamed in System Settings is still the same monitor in
        // the same place, so a rename must not orphan a saved arrangement.
        let renamed = sideBySide.map {
            DisplaySlot(key: $0.key, name: "Renamed", x: $0.x, y: $0.y,
                        width: $0.width, height: $0.height)
        }
        suite.expect(DisplayArrangementSupport.sameLayout(sideBySide, renamed),
                     "renaming a display does not change the layout")

        // One display nudged is a different arrangement.
        let nudged = sideBySide.map {
            $0.key == dell
                ? DisplaySlot(key: $0.key, name: $0.name, x: $0.x + 1, y: $0.y,
                              width: $0.width, height: $0.height)
                : $0
        }
        suite.expect(!DisplayArrangementSupport.sameLayout(sideBySide, nudged),
                     "a display moved by a point is a different layout")

        // Every display nudged together is the same arrangement in a different
        // place, which is what moving the menu bar does. Telling those two
        // apart is the whole point of comparing canonically.
        let translated = sideBySide.map {
            DisplaySlot(key: $0.key, name: $0.name, x: $0.x - 1512, y: $0.y - 40,
                        width: $0.width, height: $0.height)
        }
        suite.expect(DisplayArrangementSupport.sameLayout(sideBySide, translated),
                     "shifting every display together does not change the arrangement")
        suite.expect(DisplayArrangementSupport.canonical(sideBySide)
                        == DisplayArrangementSupport.canonical(translated),
                     "two placements of one arrangement share a canonical form")
        suite.expect(DisplayArrangementSupport.canonical(sideBySide).contains {
                        $0.x == 0 && $0.y == 0 },
                     "the canonical form starts at the origin")

        suite.expect(DisplayArrangementSupport.mainSlot(stacked)?.key == dell,
                     "the display at the origin is the main one")
        suite.expect(DisplayArrangementSupport.mainSlot(sideBySide)?.key == laptop,
                     "the arrangement's main display follows the origin, not the order")
    }

    private static func matching(_ suite: TestSuite) {
        let presets = [DisplayArrangementPreset(slots: sideBySide),
                       DisplayArrangementPreset(slots: stacked)]
        let connected: Set<String> = [laptop, dell]

        suite.expect(DisplayArrangementSupport.activePreset(in: presets, current: stacked)
                        == presets[1].id,
                     "the live layout selects the preset that describes it")
        suite.expect(DisplayArrangementSupport.activePreset(in: presets, current: [slot(laptop, 0, 0)])
                        == nil,
                     "a layout nobody saved selects no preset")

        suite.expect(presets.allSatisfy { DisplayArrangementSupport.matches($0, connected: connected) },
                     "both presets apply while both displays are connected")
        let unplugged = DisplayArrangementPreset(
            slots: [slot(laptop, 0, 0, name: "Built-in Retina Display"),
                    slot(missing, 1512, 0, name: "LG UltraFine")])
        suite.expect(!DisplayArrangementSupport.matches(unplugged, connected: connected),
                     "a preset naming an absent display cannot be applied")
        suite.expect(DisplayArrangementSupport.missingDisplayNames(unplugged, connected: connected)
                        == ["LG UltraFine"],
                     "an unusable preset can say which display it is waiting for")

        suite.expect(DisplayArrangementSupport.duplicate(of: stacked, in: presets) == presets[1].id,
                     "saving a layout already in the strip is a duplicate")
        suite.expect(DisplayArrangementSupport.duplicate(of: [slot(laptop, 0, 0)], in: presets) == nil,
                     "an unsaved layout is not a duplicate")
    }

    private static func geometry(_ suite: TestSuite) {
        guard let main = DisplayArrangementSupport.mainSlot(sideBySide),
              let other = DisplayArrangementSupport.describingSlot(
                DisplayArrangementPreset(slots: sideBySide)) else {
            suite.expect(false, "side by side has a main display and a second one")
            return
        }
        suite.expect(DisplayArrangementSupport.relation(of: other, to: main) == .right,
                     "a display placed past the main one's right edge reads as right of it")

        let stackedPreset = DisplayArrangementPreset(slots: stacked)
        if let stackedMain = DisplayArrangementSupport.mainSlot(stacked),
           let below = DisplayArrangementSupport.describingSlot(stackedPreset) {
            suite.expect(DisplayArrangementSupport.relation(of: below, to: stackedMain) == .below,
                         "a display under the main one reads as below it")
            suite.expect(DisplayArrangementSupport.relation(of: stackedMain, to: below) == .above,
                         "the relation reverses when the reference display does")
        } else {
            suite.expect(false, "stacked has a main display and a second one")
        }

        suite.expect(DisplayArrangementSupport.relation(of: slot(dell, -2560, 0, 2560, 1440),
                                                       to: slot(laptop, 0, 0)) == .left,
                     "a display placed before the main one's left edge reads as left of it")

        // A thumbnail scales to this box, so an empty or degenerate one has to
        // be refused rather than divided by.
        let box = DisplayArrangementSupport.boundingBox(sideBySide)
        suite.expect(box == DisplayArrangementSupport.Box(minX: 0, minY: 0,
                                                          width: 4072, height: 1440),
                     "the bounding box encloses every display")
        suite.expect(DisplayArrangementSupport.boundingBox([]) == nil,
                     "no displays have no bounding box")
        suite.expect(DisplayArrangementSupport.boundingBox([slot(laptop, 0, 0, 0, 0)]) == nil,
                     "a zero-sized display has no bounding box to scale against")

        let negative = DisplayArrangementSupport.boundingBox(
            [slot(laptop, 0, 0), slot(dell, -2560, -200, 2560, 1440)])
        suite.expect(negative == DisplayArrangementSupport.Box(minX: -2560, minY: -200,
                                                               width: 4072, height: 1440),
                     "displays left of and above the main one keep their negative origins")
    }

    private static func mainDisplay(_ suite: TestSuite) {
        // Side by side has the laptop at the origin; starring the DELL should
        // move the menu bar without moving the displays relative to each other.
        guard let moved = DisplayArrangementSupport.slots(sideBySide, makingMain: dell) else {
            suite.expect(false, "starring a non-main display produces a new arrangement")
            return
        }
        suite.expect(DisplayArrangementSupport.mainSlot(moved)?.key == dell,
                     "the starred display ends up at the origin")
        suite.expect(moved.first { $0.key == laptop }.map { $0.x == -1512 && $0.y == 0 } == true,
                     "the old main display keeps its place relative to the new one")

        let before = DisplayArrangementSupport.boundingBox(sideBySide)
        let after = DisplayArrangementSupport.boundingBox(moved)
        suite.expect(before?.width == after?.width && before?.height == after?.height,
                     "changing the main display does not resize the arrangement")

        suite.expect(DisplayArrangementSupport.slots(sideBySide, makingMain: laptop) == nil,
                     "starring the display that is already main is not a change")
        suite.expect(DisplayArrangementSupport.slots(sideBySide, makingMain: missing) == nil,
                     "a display that is not in the arrangement cannot be made main")

        // Round trip: star the other one back and the original coordinates
        // return. Compared exactly rather than with sameLayout, which now
        // ignores translation and would pass without the move being undone.
        guard let back = DisplayArrangementSupport.slots(moved, makingMain: laptop) else {
            suite.expect(false, "the move is reversible")
            return
        }
        suite.expect(back == DisplayArrangementSupport.normalized(sideBySide),
                     "starring the original display again restores the original placement")

        // Applying a saved arrangement must not move the menu bar: the star is
        // a separate control and a preset re-anchors on whatever is main now.
        guard let anchored = DisplayArrangementSupport.slots(sideBySide, keepingMain: dell) else {
            suite.expect(false, "a preset can be re-anchored on the current main display")
            return
        }
        suite.expect(DisplayArrangementSupport.mainSlot(anchored)?.key == dell,
                     "the preset lands with the current main display still at the origin")
        suite.expect(DisplayArrangementSupport.sameLayout(anchored, sideBySide),
                     "re-anchoring does not change which arrangement it is")
        suite.expect(DisplayArrangementSupport.slots(sideBySide, keepingMain: missing) == nil,
                     "a preset cannot be anchored on a display it does not contain")
        suite.expect(DisplayArrangementSupport.slots(sideBySide, keepingMain: laptop)
                        == DisplayArrangementSupport.normalized(sideBySide),
                     "anchoring on the display that is already main changes nothing")
    }

    private static func storage(_ suite: TestSuite) {
        let presets = [DisplayArrangementPreset(slots: sideBySide),
                       DisplayArrangementPreset(slots: stacked)]
        let restored = DisplayArrangementSupport.decode(DisplayArrangementSupport.encode(presets))
        suite.expect(restored == presets, "presets survive a round trip through the preference")
        suite.expect(restored.first?.id == presets.first?.id,
                     "a preset keeps its identity across a round trip")

        suite.expect(DisplayArrangementSupport.decode(nil).isEmpty,
                     "no saved preference means no presets")
        suite.expect(DisplayArrangementSupport.decode(Data()).isEmpty,
                     "an empty preference means no presets")
        suite.expect(DisplayArrangementSupport.decode(Data("not json".utf8)).isEmpty,
                     "a preference that is not a preset list is discarded, not crashed on")

        // Both of these can only come from a hand-edited preference.
        let single = [DisplayArrangementPreset(slots: [slot(laptop, 0, 0)])]
        suite.expect(DisplayArrangementSupport.decode(
                        DisplayArrangementSupport.encode(single)).isEmpty,
                     "a one-display preset describes no arrangement and is dropped")
        let tooMany = (0..<(DisplayArrangementSupport.maximumPresets + 5)).map { index in
            DisplayArrangementPreset(slots: [slot(laptop, 0, 0),
                                             slot(dell, 1512 + index, 0, 2560, 1440)])
        }
        suite.expect(DisplayArrangementSupport.decode(DisplayArrangementSupport.encode(tooMany)).count
                        == DisplayArrangementSupport.maximumPresets,
                     "more presets than the strip can show are trimmed to the cap")

        // CoreGraphics takes origins as Int32, so a coordinate that cannot be
        // converted has to be refused before it reaches the conversion.
        let unplaceable = [
            DisplayArrangementPreset(slots: [slot(laptop, 0, 0),
                                             slot(dell, Int(Int32.max) + 1, 0, 2560, 1440)]),
            DisplayArrangementPreset(slots: [slot(laptop, 0, 0),
                                             slot(dell, 0, Int(Int32.min) - 1, 2560, 1440)]),
            DisplayArrangementPreset(slots: [slot(laptop, 0, 0),
                                             slot(dell, 1512, 0, 0, 1440)]),
        ]
        for bad in unplaceable {
            suite.expect(DisplayArrangementSupport.decode(
                            DisplayArrangementSupport.encode([bad])).isEmpty,
                         "a preset that cannot be placed is dropped rather than applied")
        }
        suite.expect(!DisplayArrangementSupport.isPlaceable(
                        slot(dell, Int(Int32.max) + 1, 0)),
                     "an origin past Int32 is not placeable")
        suite.expect(DisplayArrangementSupport.isPlaceable(slot(dell, -2560, -200, 2560, 1440)),
                     "a negative origin from a display left of the main one is placeable")
        suite.expect(DisplayArrangementSupport.decode(
                        DisplayArrangementSupport.encode(presets)).count == 2,
                     "validation does not reject arrangements a real Mac produces")
    }
}
