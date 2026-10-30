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

        for activeFirst in [true, false] {
            var wake = MediaReloadPolicy()
            assert(wake.didSelectMedia(now: 0) == .pageEntry)
            assert(wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 100) == nil)
            assert(wake.displayChanged(isActive: activeFirst, isDimmed: activeFirst, mediaIsSelected: true, now: 130) == nil)
            assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 130) == .longDimmedWake)
            assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 131) == nil)
            // A second long interval inside the cooldown is consumed without a delayed refresh.
            assert(wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 135) == nil)
            assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 165) == nil)
            assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 200) == nil)
        }
        for duration in [29.999, 30.0, 120.0] {
            var wake = MediaReloadPolicy()
            _ = wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 10)
            assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 10 + duration) == (duration >= 30 ? .longDimmedWake : nil))
        }
        var wake = MediaReloadPolicy()
        _ = wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: false, now: 0)
        assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: false, now: 100) == nil)
        assert(wake.didSelectMedia(now: 101) == .pageEntry)
        _ = wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 110)
        wake.didEnterBackground()
        assert(wake.didBecomeActive(mediaIsSelected: true, now: 200) == .backgroundReturn)
        assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 200) == nil)
        _ = wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 210)
        assert(wake.didSelectMedia(now: 250) == .pageEntry)
        assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 251) == nil)
        _ = wake.displayChanged(isActive: false, isDimmed: true, mediaIsSelected: true, now: 260)
        assert(wake.displayChanged(isActive: true, isDimmed: false, mediaIsSelected: true, now: 310) == .longDimmedWake)

        print("PASS: long-dimmed wake threshold, cooldown, callback ordering, navigation deduplication; media entry/foreground refresh, wrist-wake stability, timer deferral and callback ordering")
    }
}
