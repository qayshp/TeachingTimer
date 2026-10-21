import Foundation

@main
struct LandmarkChecks {
    static func main() {
        let schedule = LandmarkSchedule()
        assert(schedule.isValid)
        assert(schedule.duration == 60)
        var offsets: [Double] = []
        for landmark in 1...6 {
            let group = (0..<landmark).map { schedule.pulseOffset(landmark: landmark, pulse: $0) }
            assert(group.count == landmark)
            assert(group.first == Double(landmark * 10))
            offsets += group
        }
        assert(offsets.count == 21)
        assert(offsets.first == 10)
        assert(offsets.last == 64)
        assert(zip(offsets, offsets.dropFirst()).allSatisfy { pair in pair.1 - pair.0 >= 0.799 })
        assert(schedule.progress(elapsed: -1) == 0)
        assert(schedule.progress(elapsed: 30) == 0.5)
        assert(schedule.progress(elapsed: 60) == 1)
        assert(schedule.progress(elapsed: 64) == 1)
        let start = Date(timeIntervalSince1970: 59.75)
        assert(abs(LandmarkSchedule.startAngle(at: start) - 59 * .pi / 30) < 0.0001)
        assert(!LandmarkSchedule(intervalSeconds: 0).isValid)
        assert(!LandmarkSchedule(landmarkCount: 0).isValid)
        assert(!LandmarkSchedule(pulseSpacing: 2).isValid)
        for interval in [Double.nan, .infinity, .greatestFiniteMagnitude, 86400] {
            assert(!LandmarkSchedule(intervalSeconds: interval).isValid)
        }
        assert(!LandmarkSchedule(pulseSpacing: .infinity).isValid)
        assert(!LandmarkSchedule(landmarkCount: Int.max).isValid)
        // Simulate a batch of Always-On frames evaluated at one clock instant.
        let wallNow = Date(timeIntervalSince1970: 59)
        let frames = [0.0, 10, 20, 40].map {
            schedule.frame(at: wallNow.addingTimeInterval($0), wallNow: wallNow, elapsedNow: 10)
        }
        assert(zip(frames, frames.dropFirst()).allSatisfy { $0.progress < $1.progress })
        assert(abs(frames[2].progress - 0.5) < 0.00001)
        // Forward/back clock corrections do not change the monotonic position
        // of the current or a future frame, and don't change the snapped angle.
        for correction in [-3600.0, -60, 60, 3600] {
            let corrected = wallNow.addingTimeInterval(correction)
            let frame = schedule.frame(at: corrected.addingTimeInterval(20), wallNow: corrected, elapsedNow: 10)
            assert(frame.progress == frames[2].progress && frame.isVisible)
        }
        assert(schedule.frame(at: wallNow.addingTimeInterval(50), wallNow: wallNow, elapsedNow: 10).progress == 1)
        assert(schedule.frame(at: wallNow.addingTimeInterval(54), wallNow: wallNow, elapsedNow: 10).isVisible)
        assert(!schedule.frame(at: wallNow.addingTimeInterval(55), wallNow: wallNow, elapsedNow: 10).isVisible)
        assert(!schedule.frame(at: wallNow.addingTimeInterval(300), wallNow: wallNow, elapsedNow: 10).isVisible)
        assert(!schedule.frame(at: wallNow.addingTimeInterval(-20), wallNow: wallNow, elapsedNow: 10).isVisible)
        print("PASS: six groups, 21 pulses, absolute 10–60s landmarks, spacing, clamped arc and snapped start angle")
        print("PASS: future frame batching, minute rollover, forward/back clock corrections, original 60/64.8s visual lifetime")
    }
}
