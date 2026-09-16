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
        print("PASS: six groups, 21 pulses, absolute 10–60s landmarks, spacing, clamped arc and snapped start angle")
    }
}
