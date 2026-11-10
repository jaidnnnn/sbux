import Foundation

/// What the phone sends to the watch: routines plus, per exercise, what was
/// lifted last time and the records to beat.
struct WatchExercise: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: ExerciseKind
    var restSeconds: Int
    var lastSets: [LoggedSet] = []
    var best = ExerciseBest()
}

struct WatchRoutine: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var items: [RoutineItem]
}

struct WatchContext: Codable {
    var routines: [WatchRoutine] = []
    var exercises: [WatchExercise] = []

    func exercise(_ id: UUID) -> WatchExercise? {
        exercises.first { $0.id == id }
    }
}

enum SyncKey {
    static let context = "context"
    static let workout = "workout"
}

extension Library {
    /// Sets from the most recent workout that has at least one completed set of this exercise.
    func lastSets(for exerciseID: UUID) -> [LoggedSet] {
        for workout in workouts.sorted(by: { $0.start > $1.start }) {
            let sets = workout.exercises
                .filter { $0.exerciseID == exerciseID }
                .flatMap(\.sets)
                .filter(\.done)
            if !sets.isEmpty { return sets }
        }
        return []
    }

    func allSets(for exerciseID: UUID) -> [LoggedSet] {
        workouts.flatMap(\.exercises).filter { $0.exerciseID == exerciseID }.flatMap(\.sets)
    }

    func best(for exerciseID: UUID) -> ExerciseBest {
        Stats.best(of: allSets(for: exerciseID))
    }

    /// Only exercises used by a routine go to the watch, to keep the payload small.
    func watchContext() -> WatchContext {
        let used = Set(routines.flatMap(\.items).map(\.exerciseID))
        let known = Set(exercises.map(\.id))
        return WatchContext(
            routines: routines.map { routine in
                WatchRoutine(id: routine.id, name: routine.name,
                             items: routine.items.filter { known.contains($0.exerciseID) })
            },
            exercises: exercises.filter { used.contains($0.id) }.map { exercise in
                WatchExercise(id: exercise.id, name: exercise.name, kind: exercise.kind,
                              restSeconds: exercise.restSeconds,
                              lastSets: lastSets(for: exercise.id),
                              best: best(for: exercise.id))
            })
    }

    /// Adds a workout unless it is already there (the watch may resend).
    @discardableResult
    mutating func add(_ workout: Workout) -> Bool {
        guard !workouts.contains(where: { $0.id == workout.id }) else { return false }
        workouts.append(workout)
        return true
    }
}

extension WatchContext {
    /// Lets the watch update "previous" values and records on its own, before
    /// the phone has seen the workout.
    mutating func absorb(_ workout: Workout) {
        for logged in workout.exercises {
            guard let index = exercises.firstIndex(where: { $0.id == logged.exerciseID }) else { continue }
            let done = logged.sets.filter(\.done)
            guard !done.isEmpty else { continue }
            exercises[index].lastSets = done
            done.forEach { exercises[index].best.absorb($0) }
        }
    }

    /// Builds the starting state of a workout from a routine: one row per
    /// target set, prefilled with last time's numbers.
    func newWorkout(from routine: WatchRoutine, at start: Date) -> Workout {
        let logged: [LoggedExercise] = routine.items.compactMap { item in
            guard let exercise = exercise(item.exerciseID) else { return nil }
            let count = max(1, item.targetSets)
            let sets: [LoggedSet] = (0..<count).map { index in
                guard let previous = exercise.lastSets[safe: index] ?? exercise.lastSets.last else {
                    return LoggedSet()
                }
                return LoggedSet(type: index < exercise.lastSets.count ? previous.type : .normal,
                                 weightKg: previous.weightKg, reps: previous.reps, seconds: previous.seconds)
            }
            return LoggedExercise(exerciseID: exercise.id, name: exercise.name, kind: exercise.kind, sets: sets)
        }
        return Workout(name: routine.name, start: start, end: start, exercises: logged)
    }
}

extension Workout {
    /// The workout as it should be saved: only completed sets, no empty exercises.
    func finished(at end: Date) -> Workout {
        var copy = self
        copy.end = end
        copy.exercises = exercises.compactMap { exercise in
            var e = exercise
            e.sets = exercise.sets.filter(\.done)
            return e.sets.isEmpty ? nil : e
        }
        return copy
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
