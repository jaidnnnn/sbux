import Foundation
import SwiftUI
import WatchConnectivity

final class Store: NSObject, ObservableObject, WCSessionDelegate {
    @Published var library: Library {
        didSet {
            save()
            pushToWatch()
        }
    }
    @Published private(set) var watchStatus = "Not connected"

    private static let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("library.json")

    override init() {
        if let data = try? Data(contentsOf: Store.fileURL),
           let saved = try? JSONDecoder().decode(Library.self, from: data) {
            library = saved
        } else {
            library = Library(exercises: Store.starterExercises)
        }
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: Store.fileURL, options: .atomic)
    }

    // MARK: Lookups and edits

    func exercise(_ id: UUID) -> Exercise? {
        library.exercises.first { $0.id == id }
    }

    func upsert(_ routine: Routine) {
        if let index = library.routines.firstIndex(where: { $0.id == routine.id }) {
            library.routines[index] = routine
        } else {
            library.routines.append(routine)
        }
    }

    func addExercise(named name: String, kind: ExerciseKind) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var copy = library
        copy.exercises.append(Exercise(name: trimmed, kind: kind))
        copy.exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        library = copy
    }

    /// Removes the exercise from the list and from routines. Past workouts keep it.
    func deleteExercises(_ ids: Set<UUID>) {
        var copy = library
        copy.exercises.removeAll { ids.contains($0.id) }
        for index in copy.routines.indices {
            copy.routines[index].items.removeAll { ids.contains($0.exerciseID) }
        }
        library = copy
    }

    func deleteWorkouts(_ ids: Set<UUID>) {
        library.workouts.removeAll { ids.contains($0.id) }
    }

    func importStrong(_ csv: String, pounds: Bool) throws -> ImportSummary {
        var copy = library
        let summary = try copy.importStrong(csv, poundsWhenUnlabelled: pounds)
        library = copy
        return summary
    }

    // MARK: Watch

    func pushToWatch() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        guard WCSession.default.isWatchAppInstalled else {
            watchStatus = WCSession.default.isPaired ? "Watch app not installed" : "No watch paired"
            return
        }
        do {
            let data = try JSONEncoder().encode(library.watchContext())
            try WCSession.default.updateApplicationContext([SyncKey.context: data])
            watchStatus = "Synced " + Date().formatted(date: .omitted, time: .shortened)
        } catch {
            watchStatus = "Sync failed: \(error.localizedDescription)"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.pushToWatch() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[SyncKey.workout] as? Data,
              let workout = try? JSONDecoder().decode(Workout.self, from: data) else { return }
        DispatchQueue.main.async {
            var copy = self.library
            if copy.add(workout) { self.library = copy }
        }
    }

    // MARK: Starter data

    private static let starterExercises: [Exercise] = {
        let weighted = [
            "Bench Press (Barbell)", "Bench Press (Dumbbell)", "Bent Over Row (Barbell)", "Bicep Curl (Dumbbell)",
            "Deadlift (Barbell)", "Incline Bench Press (Dumbbell)", "Lat Pulldown (Cable)",
            "Lateral Raise (Dumbbell)", "Leg Curl (Machine)", "Leg Extension (Machine)", "Leg Press",
            "Overhead Press (Barbell)", "Romanian Deadlift (Barbell)", "Seated Row (Cable)", "Squat (Barbell)",
            "Triceps Pushdown (Cable)",
        ].map { Exercise(name: $0, kind: .weighted) }
        let bodyweight = ["Chin Up", "Dip", "Pull Up", "Push Up"].map { Exercise(name: $0, kind: .bodyweight) }
        let timed = ["Dead Hang", "Plank"].map { Exercise(name: $0, kind: .timed, restSeconds: 60) }
        return (weighted + bodyweight + timed)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()
}
