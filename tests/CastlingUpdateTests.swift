// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Chlcony

import Foundation

/// Contract for the update hook's filter: Vorssaint may offer only what
/// Castling supports, and nothing at all when that list can't be read.
enum CastlingUpdateTests {
    private static func release(_ tag: String, beta: Bool = false) -> UpdateServiceSupport.ReleaseCandidate {
        // Vorssaint only offers releases with a DMG attached, so these carry one,
        // although Castling builds from source and never downloads it.
        UpdateServiceSupport.ReleaseCandidate(tagName: tag, isPrerelease: beta, isDraft: false,
                                              dmgURL: URL(string: "https://example.invalid/\(tag).dmg"),
                                              dmgExpectedBytes: nil, body: nil)
    }

    private static func manifest(_ entries: [(String, String)]) -> Data {
        let releases = entries.map { #"{"version":"\#($0.0)","commit":"x","patches":"cl-2026-10-18","patch":"\#($0.0)+cl-2026-10-18","status":"\#($0.1)"}"# }
        return Data(#"{"upstream":"vorssaint/vorssaint-utils","releases":[\#(releases.joined(separator: ","))]}"#.utf8)
    }

    static func run(_ suite: TestSuite) {
        let listed = CastlingUpdateSupport.supportedVersions(fromManifest: manifest([
            ("3.4.1", "supported"), ("3.4.2", "in-development"), ("3.4.0", "unsupported"),
        ]))
        suite.expect(listed == ["3.4.1"], "only supported entries count, got \(String(describing: listed))")
        suite.expect(CastlingUpdateSupport.supportedVersions(fromManifest: Data("not json".utf8)) == nil,
                     "an unreadable list is nil, not empty")
        suite.expect(CastlingUpdateSupport.supportedVersions(fromManifest: Data(#"{"releases":[]}"#.utf8)) == [],
                     "an empty list is empty, not nil")

        let offered = [release("v3.4.2"), release("v3.4.1"), release("v3.4.2-beta.1", beta: true)]
        let kept = CastlingUpdateSupport.keep(offered, supported: ["3.4.1"]).map(\.tagName)
        suite.expect(kept == ["v3.4.1"], "unsupported releases are dropped, got \(kept)")
        suite.expect(CastlingUpdateSupport.keep(offered, supported: nil).isEmpty,
                     "nothing is offered when the list can't be read")
        suite.expect(CastlingUpdateSupport.keep(offered, supported: []).isEmpty,
                     "nothing is offered when nothing is supported")
        suite.expect(CastlingUpdateSupport.keep(offered, supported: ["3.4.2-beta.1"]).map(\.tagName) == ["v3.4.2-beta.1"],
                     "a supported beta is offered")
        suite.expect(CastlingUpdateSupport.keep([release("V3.4.1"), release(" v3.4.1 ")], supported: ["3.4.1"]).count == 2,
                     "tag names are trimmed the way Vorssaint trims them")
        suite.expect(CastlingUpdateSupport.keep([release("v3.4.10")], supported: ["3.4.1"]).isEmpty,
                     "versions match exactly, not by prefix")

        // The filter feeds Vorssaint's own choice: with only an older release
        // supported, nothing newer than the running version remains.
        let chosen = UpdateServiceSupport.selectUpdate(
            from: CastlingUpdateSupport.keep(offered, supported: ["3.4.1"]),
            currentVersion: "3.4.1", includeBetas: true)
        suite.expect(chosen == nil, "no update is chosen when only the current version is supported")
        let next = UpdateServiceSupport.selectUpdate(
            from: CastlingUpdateSupport.keep(offered, supported: ["3.4.1", "3.4.2"]),
            currentVersion: "3.4.1", includeBetas: false)
        suite.expect(next?.tagName == "v3.4.2", "the supported newer release is chosen")
    }
}
