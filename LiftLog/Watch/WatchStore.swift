import Foundation
import SwiftUI
import WatchConnectivity
import WatchKit

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var context: WatchContext
    @Published private(set) var active: Workout? {
        didSet { Disk.save(active, to: "active.json") }
    }
    @Published private(set) var restEnd: Date?
    @Published private(set) var prMessage: String?

    private let health = HealthManager()
    private var restTimer: Timer?

    override init() {
        context = Disk.load(WatchContext.self, from: "context.json") ?? WatchContext()
        active = Disk.load(Workout.self, from: "active.json")
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        // Relaunched in the middle of a workout: pick the session back up.
        if let active { health.start(at: active.start) }
    }

    // MARK: Workout

    func start(_ routine: WatchRoutine) {
        let now = Date()
        active = context.newWorkout(from: routine, at: now)
        prMessage = nil
        health.start(at: now)
    }

    func exercise(at index: Int) -> LoggedExercise? {
        active?.exercises[safe: index]
    }

    /// Last time's set in the same position, shown as "prev".
    func previousSet(exercise e: Int, set s: Int) -> LoggedSet? {
        guard let logged = exercise(at: e) else { return nil }
        return context.exercise(logged.exerciseID)?.lastSets[safe: s]
    }

    func log(exercise e: Int, set s: Int, values: LoggedSet) {
        guard var workout = active,
              let logged = workout.exercises[safe: e],
              logged.sets.indices.contains(s) else { return }

        var previousBest = context.exercise(logged.exerciseID)?.best ?? ExerciseBest()
        for (index, other) in logged.sets.enumerated() where index != s {
            previousBest.absorb(other)
        }

        var set = values
        set.id = logged.sets[s].id
        set.done = true
        workout.exercises[e].sets[s] = set

        // An empty next set starts from what was just done.
        if let next = logged.sets[safe: s + 1], !next.done,
           next.weightKg == 0, next.reps == 0, next.seconds == 0 {
            workout.exercises[e].sets[s + 1].weightKg = set.weightKg
            workout.exercises[e].sets[s + 1].reps = set.reps
            workout.exercises[e].sets[s + 1].seconds = set.seconds
        }
        active = workout

        let records = Stats.records(beatenBy: set, kind: logged.kind, previous: previousBest)
        if records.isEmpty {
            prMessage = nil
            WKInterfaceDevice.current().play(.click)
        } else {
            prMessage = "PR: " + records.joined(separator: ", ")
            WKInterfaceDevice.current().play(.success)
        }
        startRest(seconds: context.exercise(logged.exerciseID)?.restSeconds ?? 90)
    }

    func addSet(exercise e: Int) {
        guard var workout = active, let logged = workout.exercises[safe: e] else { return }
        var set = LoggedSet()
        if let last = logged.sets.last {
            set.weightKg = last.weightKg
            set.reps = last.reps
            set.seconds = last.seconds
        }
        workout.exercises[e].sets.append(set)
        active = workout
    }

    func removeSets(exercise e: Int, at offsets: IndexSet) {
        guard var workout = active, workout.exercises.indices.contains(e) else { return }
        workout.exercises[e].sets.remove(atOffsets: offsets)
        active = workout
    }

    func finish() {
        guard let workout = active else { return }
        let now = Date()
        let finished = workout.finished(at: now)
        let hasSets = !finished.exercises.isEmpty
        if hasSets {
            context.absorb(finished)
            Disk.save(context, to: "context.json")
            if let data = try? JSONEncoder().encode(finished) {
                // Queued by the system and delivered when the phone is next available.
                WCSession.default.transferUserInfo([SyncKey.workout: data])
            }
        }
        health.end(save: hasSets, at: now)
        clear()
    }

    func discard() {
        health.end(save: false, at: Date())
        clear()
    }

    private func clear() {
        skipRest()
        prMessage = nil
        active = nil
    }

    // MARK: Rest timer

    func startRest(seconds: Int) {
        guard seconds > 0 else { return skipRest() }
        scheduleRest(until: Date().addingTimeInterval(TimeInterval(seconds)))
    }

    func extendRest(by seconds: Int) {
        guard let restEnd else { return }
        scheduleRest(until: restEnd.addingTimeInterval(TimeInterval(seconds)))
    }

    func skipRest() {
        restTimer?.invalidate()
        restTimer = nil
        restEnd = nil
    }

    private func scheduleRest(until end: Date) {
        restTimer?.invalidate()
        restEnd = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            WKInterfaceDevice.current().play(.notification)
            self?.restTimer = nil
            self?.restEnd = nil
        }
        RunLoop.main.add(timer, forMode: .common)
        restTimer = timer
    }

    // MARK: WatchConnectivity

    private func apply(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[SyncKey.context] as? Data,
              let decoded = try? JSONDecoder().decode(WatchContext.self, from: data) else { return }
        DispatchQueue.main.async {
            self.context = decoded
            Disk.save(decoded, to: "context.json")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}

enum Disk {
    private static func url(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Saving nil removes the file.
    static func save<T: Encodable>(_ value: T?, to name: String) {
        guard let value else {
            try? FileManager.default.removeItem(at: url(name))
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }
}
