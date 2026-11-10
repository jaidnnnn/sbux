import Foundation

struct ImportSummary: Equatable {
    var workouts = 0
    var skippedDuplicates = 0
    var newExercises = 0
    var newRoutines = 0
    var sets = 0
}

enum ImportError: Error, LocalizedError {
    case missingColumn(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingColumn(let name): return "This doesn't look like a Strong export: no “\(name)” column."
        case .empty: return "The file has no workout rows."
        }
    }
}

/// Reads the CSV that Strong produces from Settings → Export Data. Handles
/// both the comma and the semicolon layouts by looking columns up by name.
enum StrongImporter {
    static let poundsToKg = 0.45359237

    /// Splits CSV text into rows of fields. Supports quoted fields with
    /// embedded delimiters, quotes and line breaks.
    static func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = text.makeIterator()
        var pending: Character? = nil

        func endRow() {
            row.append(field)
            field = ""
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let c = pending ?? chars.next() {
            pending = nil
            if quoted {
                if c == "\"" {
                    if let following = chars.next() {
                        if following == "\"" { field.append("\"") } else { quoted = false; pending = following }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                quoted = true
            } else if c == delimiter {
                row.append(field)
                field = ""
            } else if c == "\n" || c == "\r\n" {
                endRow()
            } else if c == "\r" {
                endRow()
            } else {
                field.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    static func detectDelimiter(_ text: String) -> Character {
        let header = text.prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" }
        return header.filter { $0 == ";" }.count > header.filter { $0 == "," }.count ? ";" : ","
    }

    /// "1h 5m", "45m", "30s" or plain seconds.
    static func parseDuration(_ raw: String) -> TimeInterval {
        let text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let seconds = Double(text) { return seconds }
        var total = 0.0
        var number = ""
        for c in text {
            if c.isNumber || c == "." {
                number.append(c)
            } else {
                let value = Double(number) ?? 0
                switch c {
                case "h": total += value * 3600
                case "m": total += value * 60
                case "s": total += value
                default: continue
                }
                number = ""
            }
        }
        return total
    }

    static func parseDate(_ raw: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw.trimmingCharacters(in: .whitespaces)) { return date }
        }
        return nil
    }

    private static func number(_ raw: String) -> Double {
        Double(raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    struct ParsedWorkout {
        var name: String
        var start: Date
        var duration: TimeInterval
        var notes: String
        /// Exercise name and its sets, in the order they appear.
        var exercises: [(name: String, sets: [LoggedSet])]
    }

    /// - Parameter poundsWhenUnlabelled: older exports have a bare "Weight"
    ///   column in whatever unit the app was set to; pass true if that was lb.
    static func parse(_ csv: String, poundsWhenUnlabelled: Bool = false,
                      timeZone: TimeZone = .current) throws -> [ParsedWorkout] {
        var text = csv
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let rows = parseCSV(text, delimiter: detectDelimiter(text))
        guard let header = rows.first else { throw ImportError.empty }
        let names = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        func column(_ prefix: String, required: Bool = false) throws -> Int? {
            if let index = names.firstIndex(where: { $0 == prefix || $0.hasPrefix(prefix + " ") }) { return index }
            if required { throw ImportError.missingColumn(prefix.capitalized) }
            return nil
        }
        let dateCol = try column("date", required: true)!
        let workoutCol = try column("workout name", required: true)!
        let exerciseCol = try column("exercise name", required: true)!
        let orderCol = try column("set order")
        let weightCol = try column("weight")
        let repsCol = try column("reps")
        let secondsCol = try column("seconds")
        let durationCol = try column("duration")
        let notesCol = try column("workout notes")

        var factor = poundsWhenUnlabelled ? poundsToKg : 1
        if let weightCol {
            if names[weightCol].contains("lb") { factor = poundsToKg }
            if names[weightCol].contains("kg") { factor = 1 }
        }

        var workouts: [ParsedWorkout] = []
        var indexByKey: [String: Int] = [:]

        for row in rows.dropFirst() {
            func cell(_ index: Int?) -> String {
                guard let index, index < row.count else { return "" }
                return row[index]
            }
            guard let start = parseDate(cell(dateCol), timeZone: timeZone) else { continue }
            let exerciseName = cell(exerciseCol).trimmingCharacters(in: .whitespaces)
            guard !exerciseName.isEmpty else { continue }

            let order = cell(orderCol).trimmingCharacters(in: .whitespaces).lowercased()
            var type = SetType.normal
            switch order {
            case "w": type = .warmup
            case "d": type = .drop
            case "f": type = .failure
            case "rest timer", "note": continue
            default: break
            }

            let weight = (number(cell(weightCol)) * factor * 100).rounded() / 100
            let reps = Int(number(cell(repsCol)))
            let seconds = Int(number(cell(secondsCol)))
            guard reps > 0 || seconds > 0 else { continue }
            let set = LoggedSet(type: type, weightKg: weight, reps: reps, seconds: seconds, done: true)

            let workoutName = cell(workoutCol).trimmingCharacters(in: .whitespaces)
            let key = "\(start.timeIntervalSince1970)|\(workoutName)"
            let w: Int
            if let existing = indexByKey[key] {
                w = existing
            } else {
                w = workouts.count
                indexByKey[key] = w
                workouts.append(ParsedWorkout(name: workoutName.isEmpty ? "Workout" : workoutName,
                                              start: start,
                                              duration: parseDuration(cell(durationCol)),
                                              notes: cell(notesCol),
                                              exercises: []))
            }
            if let e = workouts[w].exercises.firstIndex(where: { $0.name == exerciseName }) {
                workouts[w].exercises[e].sets.append(set)
            } else {
                workouts[w].exercises.append((exerciseName, [set]))
            }
        }
        guard !workouts.isEmpty else { throw ImportError.empty }
        return workouts.sorted { $0.start < $1.start }
    }

    static func inferKind(_ sets: [LoggedSet]) -> ExerciseKind {
        if sets.contains(where: { $0.reps > 0 && $0.weightKg > 0 }) { return .weighted }
        if sets.contains(where: { $0.reps > 0 }) { return .bodyweight }
        return .timed
    }
}

extension Library {
    /// Merges a Strong export: creates missing exercises, adds workouts that
    /// are not already present, and makes a routine for each workout name that
    /// has none, modelled on the latest workout of that name.
    mutating func importStrong(_ csv: String, poundsWhenUnlabelled: Bool = false,
                               defaultRest: Int = 90, timeZone: TimeZone = .current) throws -> ImportSummary {
        let parsed = try StrongImporter.parse(csv, poundsWhenUnlabelled: poundsWhenUnlabelled, timeZone: timeZone)
        var summary = ImportSummary()

        var setsByName: [String: [LoggedSet]] = [:]
        for workout in parsed {
            for exercise in workout.exercises {
                setsByName[exercise.name.lowercased(), default: []] += exercise.sets
            }
        }
        var idByName: [String: UUID] = [:]
        for exercise in exercises { idByName[exercise.name.lowercased()] = exercise.id }

        var latestByRoutineName: [String: Workout] = [:]
        for item in parsed {
            if workouts.contains(where: { $0.name == item.name && abs($0.start.timeIntervalSince(item.start)) < 1 }) {
                summary.skippedDuplicates += 1
                continue
            }
            var workout = Workout(name: item.name, start: item.start,
                                  end: item.start.addingTimeInterval(item.duration), notes: item.notes)
            for exercise in item.exercises {
                let key = exercise.name.lowercased()
                let kind: ExerciseKind
                if let id = idByName[key], let known = exercises.first(where: { $0.id == id }) {
                    kind = known.kind
                } else {
                    kind = StrongImporter.inferKind(setsByName[key] ?? exercise.sets)
                    let created = Exercise(name: exercise.name, kind: kind, restSeconds: defaultRest)
                    exercises.append(created)
                    idByName[key] = created.id
                    summary.newExercises += 1
                }
                workout.exercises.append(LoggedExercise(exerciseID: idByName[key]!, name: exercise.name,
                                                        kind: kind, sets: exercise.sets))
                summary.sets += exercise.sets.count
            }
            workouts.append(workout)
            latestByRoutineName[item.name] = workout
            summary.workouts += 1
        }

        for (name, workout) in latestByRoutineName.sorted(by: { $0.key < $1.key })
        where !routines.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            let items = workout.exercises.map { exercise in
                RoutineItem(exerciseID: exercise.exerciseID,
                            targetSets: max(1, exercise.sets.filter { $0.type != .warmup }.count))
            }
            routines.append(Routine(name: name, items: items))
            summary.newRoutines += 1
        }
        exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return summary
    }
}
