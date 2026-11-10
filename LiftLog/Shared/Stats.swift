import Foundation

/// Best-ever numbers for one exercise. Warm-up sets never count.
struct ExerciseBest: Codable, Hashable {
    var weightKg: Double = 0
    var e1RM: Double = 0
    var setVolume: Double = 0
    var reps: Int = 0
    var seconds: Int = 0

    mutating func absorb(_ set: LoggedSet) {
        guard set.done, set.type != .warmup else { return }
        weightKg = max(weightKg, set.weightKg)
        e1RM = max(e1RM, Stats.e1RM(weightKg: set.weightKg, reps: set.reps))
        setVolume = max(setVolume, Stats.volume(of: set))
        reps = max(reps, set.reps)
        seconds = max(seconds, set.seconds)
    }
}

enum Stats {
    /// Epley estimate. A single is its own 1RM.
    static func e1RM(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    static func volume(of set: LoggedSet) -> Double {
        guard set.done, set.type != .warmup else { return 0 }
        return set.weightKg * Double(set.reps)
    }

    static func volume(of exercise: LoggedExercise) -> Double {
        exercise.sets.reduce(0) { $0 + volume(of: $1) }
    }

    static func volume(of workout: Workout) -> Double {
        workout.exercises.reduce(0) { $0 + volume(of: $1) }
    }

    static func best(of sets: [LoggedSet]) -> ExerciseBest {
        var best = ExerciseBest()
        sets.forEach { best.absorb($0) }
        return best
    }

    /// Names of the records a set beats, given the best before it. Empty when
    /// there is no earlier record to beat, so a first session is not all PRs.
    static func records(beatenBy set: LoggedSet, kind: ExerciseKind, previous: ExerciseBest) -> [String] {
        guard set.done, set.type != .warmup else { return [] }
        var out: [String] = []
        switch kind {
        case .weighted:
            guard previous.weightKg > 0 else { return [] }
            if set.weightKg > previous.weightKg { out.append("Weight") }
            if e1RM(weightKg: set.weightKg, reps: set.reps) > previous.e1RM + 0.001 { out.append("1RM") }
            if volume(of: set) > previous.setVolume + 0.001 { out.append("Volume") }
        case .bodyweight:
            guard previous.reps > 0 else { return [] }
            if set.reps > previous.reps { out.append("Reps") }
            if previous.weightKg > 0, set.weightKg > previous.weightKg { out.append("Weight") }
        case .timed:
            guard previous.seconds > 0 else { return [] }
            if set.seconds > previous.seconds { out.append("Time") }
        }
        return out
    }
}

enum Format {
    /// 60 -> "60", 62.5 -> "62.5"
    static func kg(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func set(_ set: LoggedSet, kind: ExerciseKind) -> String {
        switch kind {
        case .weighted:
            return "\(kg(set.weightKg)) kg × \(set.reps)"
        case .bodyweight:
            return set.weightKg > 0 ? "+\(kg(set.weightKg)) kg × \(set.reps)" : "\(set.reps) reps"
        case .timed:
            return set.weightKg > 0 ? "\(kg(set.weightKg)) kg · \(clock(set.seconds))" : clock(set.seconds)
        }
    }
}
