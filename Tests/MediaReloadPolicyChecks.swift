// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@main
struct MediaReloadPolicyChecks {
    static func main() {
        var policy = MediaReloadPolicy()

        // Initial activation and repeated inactive/active wrist wakes must not
        // discard native controls, including when already looking at media.
        for _ in 0..<100 {
            assert(policy.didBecomeActive(mediaIsSelected: true) == nil)
            assert(policy.didBecomeActive(mediaIsSelected: false) == nil)
        }
        assert(policy.didSelectMedia() == .pageEntry)
        assert(policy.didBecomeActive(mediaIsSelected: true) == nil)

        // A real background -> inactive -> active return refreshes once. The
        // intermediate inactive phase intentionally has no policy action.
        policy.didEnterBackground()
        policy.didEnterBackground()
        assert(policy.didBecomeActive(mediaIsSelected: true) == .backgroundReturn)
        assert(policy.didBecomeActive(mediaIsSelected: true) == nil)

        // Returning to the timer leaves media untouched until it is selected.
        policy.didEnterBackground()
        assert(policy.didBecomeActive(mediaIsSelected: false) == nil)
        assert(policy.didSelectMedia() == .pageEntry)
        assert(policy.didBecomeActive(mediaIsSelected: true) == nil)

        // A page entry arriving before the active callback consumes the pending
        // background refresh, avoiding a second replacement of that fresh view.
        policy.didEnterBackground()
        assert(policy.didSelectMedia() == .pageEntry)
        assert(policy.didBecomeActive(mediaIsSelected: true) == nil)

        // Manual recovery from the Class sheet also selects media. It must
        // replace once, not again when the selection's onChange is delivered.
        assert(policy.manualReload(willSelectMedia: true) == .manual)
        assert(policy.didSelectMedia() == nil)
        assert(policy.didSelectMedia() == .pageEntry)
        assert(policy.manualReload(willSelectMedia: false) == .manual)
        assert(policy.didSelectMedia() == .pageEntry)

        policy.didEnterBackground()
        assert(policy.manualReload(willSelectMedia: true) == .manual)
        assert(policy.didBecomeActive(mediaIsSelected: true) == nil)
        assert(policy.didSelectMedia() == nil)
        policy.didEnterBackground()
        assert(policy.didBecomeActive(mediaIsSelected: true) == .backgroundReturn)

        print("PASS: media entry/foreground refresh, wrist-wake stability, timer deferral, manual deduplication and callback ordering")
    }
}
