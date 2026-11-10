import XCTest
@testable import LiftLogCore

final class CoreTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!

    let oldFormat = #"""
    Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
    2024-01-01 18:00:00,"Push, Day",1h 5m,Bench Press (Barbell),W,40,10,0,0,,"felt ""good""",
    2024-01-01 18:00:00,"Push, Day",1h 5m,Bench Press (Barbell),1,80,8,0,0,,,
    2024-01-01 18:00:00,"Push, Day",1h 5m,Bench Press (Barbell),2,80,7,0,0,,,
    2024-01-01 18:00:00,"Push, Day",1h 5m,Pull Up,1,0,12,0,0,,,
    2024-01-01 18:00:00,"Push, Day",1h 5m,Plank,1,0,0,0,60,,,
    2024-01-08 18:00:00,"Push, Day",45m,Bench Press (Barbell),1,82.5,8,0,0,,,
    2024-01-08 18:00:00,"Push, Day",45m,Bench Press (Barbell),D,60,12,0,0,,,
    """#

    let newFormat = "Workout #;Date;Workout Name;Duration (sec);Exercise Name;Set Order;Weight (lbs);Reps;RPE;Distance (meters);Seconds;Notes;Workout Notes\r\n"
        + "1;2024-02-01 07:30:00;Legs;3600;Squat (Barbell);1;220;5;;;0;;\r\n"
        + "1;2024-02-01 07:30:00;Legs;3600;Squat (Barbell);Rest Timer;;;;;120;;\r\n"
        + "1;2024-02-01 07:30:00;Legs;3600;Squat (Barbell);F;220;4;;;0;;\r\n"

    func testParsesOldCommaFormat() throws {
        let workouts = try StrongImporter.parse(oldFormat, timeZone: utc)
        XCTAssertEqual(workouts.count, 2)
        let first = workouts[0]
        XCTAssertEqual(first.name, "Push, Day")
        XCTAssertEqual(first.duration, 3900)
        XCTAssertEqual(first.notes, "felt \"good\"")
        XCTAssertEqual(first.exercises.map(\.name), ["Bench Press (Barbell)", "Pull Up", "Plank"])
        XCTAssertEqual(first.exercises[0].sets.map(\.type), [.warmup, .normal, .normal])
        XCTAssertEqual(first.exercises[0].sets[1].weightKg, 80)
        XCTAssertEqual(first.exercises[2].sets[0].seconds, 60)
        XCTAssertEqual(workouts[1].exercises[0].sets.map(\.type), [.normal, .drop])
        XCTAssertEqual(workouts[1].exercises[0].sets[0].weightKg, 82.5)
        XCTAssertEqual(first.start.timeIntervalSince1970, 1704132000)
    }

    func testParsesSemicolonPoundsFormat() throws {
        let workouts = try StrongImporter.parse(newFormat, timeZone: utc)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].duration, 3600)
        let sets = workouts[0].exercises[0].sets
        XCTAssertEqual(sets.count, 2, "rest timer rows are not sets")
        XCTAssertEqual(sets[0].weightKg, 99.79)
        XCTAssertEqual(sets[1].type, .failure)
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try StrongImporter.parse("a,b\n1,2\n"))
        XCTAssertThrowsError(try StrongImporter.parse(""))
    }

    func testImportBuildsLibraryAndIsRepeatable() throws {
        var library = Library()
        let summary = try library.importStrong(oldFormat, timeZone: utc)
        XCTAssertEqual(summary, ImportSummary(workouts: 2, skippedDuplicates: 0, newExercises: 3, newRoutines: 1, sets: 7))
        XCTAssertEqual(library.exercises.map(\.kind), [.weighted, .timed, .bodyweight]) // sorted by name
        XCTAssertEqual(library.routines.count, 1)
        // Routine mirrors the latest "Push, Day": one exercise, two working sets.
        XCTAssertEqual(library.routines[0].items.map(\.targetSets), [2])

        let again = try library.importStrong(oldFormat, timeZone: utc)
        XCTAssertEqual(again.workouts, 0)
        XCTAssertEqual(again.skippedDuplicates, 2)
        XCTAssertEqual(library.workouts.count, 2)
        XCTAssertEqual(library.exercises.count, 3)
    }

    func testStatsAndRecords() throws {
        XCTAssertEqual(Stats.e1RM(weightKg: 100, reps: 1), 100)
        XCTAssertEqual(Stats.e1RM(weightKg: 90, reps: 10), 120, accuracy: 0.0001)

        var library = Library()
        _ = try library.importStrong(oldFormat, timeZone: utc)
        let bench = library.exercises.first { $0.name.hasPrefix("Bench") }!
        let best = library.best(for: bench.id)
        XCTAssertEqual(best.weightKg, 82.5)
        XCTAssertEqual(best.setVolume, 720) // 60 × 12 drop set
        XCTAssertEqual(Stats.volume(of: library.workouts[0]), 80 * 8 + 80 * 7, "warm-up excluded")

        let heavier = LoggedSet(weightKg: 85, reps: 5, done: true)
        XCTAssertEqual(Stats.records(beatenBy: heavier, kind: .weighted, previous: best), ["Weight"])
        let warmup = LoggedSet(type: .warmup, weightKg: 200, reps: 20, done: true)
        XCTAssertEqual(Stats.records(beatenBy: warmup, kind: .weighted, previous: best), [])
        XCTAssertEqual(Stats.records(beatenBy: heavier, kind: .weighted, previous: ExerciseBest()), [],
                       "no records on a first session")
    }

    func testWatchRoundTrip() throws {
        var library = Library()
        _ = try library.importStrong(oldFormat, timeZone: utc)
        var context = library.watchContext()
        XCTAssertEqual(context.exercises.count, 1, "only exercises used by a routine are sent")

        // Survives JSON, as it does over WatchConnectivity.
        context = try JSONDecoder().decode(WatchContext.self, from: JSONEncoder().encode(context))
        let start = Date(timeIntervalSince1970: 1_705_000_000)
        var workout = context.newWorkout(from: context.routines[0], at: start)
        let sets = workout.exercises[0].sets
        XCTAssertEqual(sets.map(\.weightKg), [82.5, 60], "prefilled from last time")
        XCTAssertEqual(sets.map(\.type), [.normal, .drop])
        XCTAssertFalse(sets.contains(where: \.done))

        workout.exercises[0].sets[0].weightKg = 85
        workout.exercises[0].sets[0].done = true
        let finished = workout.finished(at: start.addingTimeInterval(1800))
        XCTAssertEqual(finished.exercises[0].sets.count, 1, "unlogged sets are dropped")
        XCTAssertEqual(finished.duration, 1800)

        context.absorb(finished)
        XCTAssertEqual(context.exercises[0].best.weightKg, 85)
        XCTAssertEqual(context.exercises[0].lastSets.count, 1)

        XCTAssertTrue(library.add(finished))
        XCTAssertFalse(library.add(finished), "a resent workout is not duplicated")
        XCTAssertEqual(library.lastSets(for: finished.exercises[0].exerciseID).first?.weightKg, 85)
    }

    func testFormatting() {
        XCTAssertEqual(Format.kg(60), "60")
        XCTAssertEqual(Format.kg(62.5), "62.5")
        XCTAssertEqual(Format.clock(95), "1:35")
        XCTAssertEqual(Format.duration(3900), "1h 5m")
    }
}
