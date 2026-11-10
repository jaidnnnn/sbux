import Foundation

enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case weighted, bodyweight, timed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weighted: return "Weight × reps"
        case .bodyweight: return "Bodyweight reps"
        case .timed: return "Timed"
        }
    }
}

enum SetType: String, Codable, CaseIterable, Identifiable {
    case normal, warmup, drop, failure
    var id: String { rawValue }
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warmup: return "Warm-up"
        case .drop: return "Drop set"
        case .failure: return "Failure"
        }
    }
    /// Short badge shown in set rows, as in Strong.
    var badge: String? {
        switch self {
        case .normal: return nil
        case .warmup: return "W"
        case .drop: return "D"
        case .failure: return "F"
        }
    }
    var next: SetType {
        let all = SetType.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: ExerciseKind = .weighted
    var restSeconds: Int = 90
}

struct RoutineItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: UUID
    var targetSets: Int = 3
}

struct Routine: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var items: [RoutineItem] = []
}

struct LoggedSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: SetType = .normal
    var weightKg: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var done: Bool = false
}

struct LoggedExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: UUID
    var name: String
    var kind: ExerciseKind
    var sets: [LoggedSet] = []
}

struct Workout: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var start: Date
    var end: Date
    var exercises: [LoggedExercise] = []
    var notes: String = ""

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// Everything the phone persists.
struct Library: Codable {
    var exercises: [Exercise] = []
    var routines: [Routine] = []
    var workouts: [Workout] = []
}
