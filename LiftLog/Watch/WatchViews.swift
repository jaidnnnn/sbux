import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        if store.active != nil {
            WorkoutView()
        } else {
            RoutineListView()
        }
    }
}

struct RoutineListView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            if store.context.routines.isEmpty {
                Text("No routines yet. Create one in LiftLog on your iPhone, then open this app again.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            ForEach(store.context.routines) { routine in
                Button {
                    store.start(routine)
                } label: {
                    VStack(alignment: .leading) {
                        Text(routine.name).font(.headline)
                        Text("\(routine.items.count) exercises")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Routines")
    }
}

struct WorkoutView: View {
    @EnvironmentObject var store: WatchStore
    @State private var confirmingFinish = false

    var body: some View {
        List {
            RestBanner()
            if let workout = store.active {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    NavigationLink(destination: ExerciseView(exerciseIndex: index)) {
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(.headline).lineLimit(2)
                            Text("\(exercise.sets.filter(\.done).count)/\(exercise.sets.count) sets")
                                .font(.footnote)
                                .foregroundColor(exercise.sets.allSatisfy(\.done) ? .green : .secondary)
                        }
                    }
                }
                Section {
                    HStack {
                        Text(workout.start, style: .timer)
                        Spacer()
                        Text("\(Format.kg(Stats.volume(of: workout))) kg")
                    }
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.secondary)
                    Button("Finish") { confirmingFinish = true }
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle(store.active?.name ?? "Workout")
        .confirmationDialog("Finish workout?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Save workout") { store.finish() }
            Button("Discard workout", role: .destructive) { store.discard() }
            Button("Keep going", role: .cancel) {}
        }
    }
}

/// Rest countdown and the latest record, shown at the top of workout lists.
struct RestBanner: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        if let message = store.prMessage {
            Label(message, systemImage: "star.fill")
                .font(.footnote.bold())
                .foregroundColor(.yellow)
        }
        if let end = store.restEnd {
            VStack(spacing: 4) {
                HStack {
                    Text("Rest").foregroundColor(.secondary)
                    Spacer()
                    Text(end, style: .timer)
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.orange)
                }
                HStack {
                    Button("+30s") { store.extendRest(by: 30) }
                    Button("Skip") { store.skipRest() }
                }
                .buttonStyle(BorderedButtonStyle())
                .font(.footnote)
            }
        }
    }
}

struct ExerciseView: View {
    @EnvironmentObject var store: WatchStore
    let exerciseIndex: Int

    var body: some View {
        List {
            RestBanner()
            if let exercise = store.exercise(at: exerciseIndex) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    NavigationLink(destination: SetEditorView(exerciseIndex: exerciseIndex, setIndex: index)) {
                        SetRow(number: index + 1, set: set, kind: exercise.kind,
                               previous: store.previousSet(exercise: exerciseIndex, set: index))
                    }
                }
                .onDelete { store.removeSets(exercise: exerciseIndex, at: $0) }
                Button {
                    store.addSet(exercise: exerciseIndex)
                } label: {
                    Label("Add set", systemImage: "plus")
                }
            }
        }
        .navigationTitle(store.exercise(at: exerciseIndex)?.name ?? "")
    }
}

struct SetRow: View {
    let number: Int
    let set: LoggedSet
    let kind: ExerciseKind
    let previous: LoggedSet?

    var body: some View {
        HStack {
            Text(set.type.badge ?? "\(number)")
                .font(.footnote.bold())
                .foregroundColor(set.type == .normal ? .secondary : .orange)
                .frame(width: 16)
            VStack(alignment: .leading) {
                Text(Format.set(set, kind: kind))
                    .font(.body.monospacedDigit())
                    .foregroundColor(set.done ? .primary : .secondary)
                if let previous {
                    Text("prev \(Format.set(previous, kind: kind))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if set.done {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            }
        }
    }
}

struct SetEditorView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let exerciseIndex: Int
    let setIndex: Int

    @State private var loaded = false
    @State private var type = SetType.normal
    @State private var weight = 0.0
    @State private var reps = 0.0
    @State private var seconds = 0.0
    @State private var stopwatchStart: Date?

    private var kind: ExerciseKind { store.exercise(at: exerciseIndex)?.kind ?? .weighted }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                switch kind {
                case .weighted:
                    weightRow(unit: "kg")
                    repsRow
                case .bodyweight:
                    repsRow
                    weightRow(unit: "+kg")
                case .timed:
                    CrownRow(value: $seconds, range: 0...3600, crownStep: 5, buttonStep: 1,
                             unit: "time") { Format.clock(Int($0)) }
                    stopwatchButton
                }
                HStack {
                    Button(type.badge ?? "N") { type = type.next }
                        .foregroundColor(type == .normal ? .primary : .orange)
                        .frame(width: 48)
                    Button("Log") { log() }
                        .tint(.green)
                }
                .buttonStyle(BorderedButtonStyle())
                Text(type.label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Set \(setIndex + 1)")
        .onAppear(perform: load)
    }

    private func weightRow(unit: String) -> some View {
        CrownRow(value: $weight, range: 0...500, crownStep: 2.5, buttonStep: 0.5, unit: unit) { Format.kg($0) }
    }

    private var repsRow: some View {
        CrownRow(value: $reps, range: 0...100, crownStep: 1, buttonStep: 1, unit: "reps") { String(Int($0)) }
    }

    private var stopwatchButton: some View {
        Button {
            if let start = stopwatchStart {
                seconds = Date().timeIntervalSince(start).rounded()
                stopwatchStart = nil
            } else {
                stopwatchStart = Date()
            }
        } label: {
            if let start = stopwatchStart {
                HStack {
                    Text("Stop")
                    Text(start, style: .timer).monospacedDigit()
                }
            } else {
                Label("Stopwatch", systemImage: "stopwatch")
            }
        }
        .buttonStyle(BorderedButtonStyle())
        .foregroundColor(stopwatchStart == nil ? .primary : .red)
    }

    private func load() {
        guard !loaded, let set = store.exercise(at: exerciseIndex)?.sets[safe: setIndex] else { return }
        loaded = true
        type = set.type
        weight = set.weightKg
        reps = Double(set.reps)
        seconds = Double(set.seconds)
    }

    private func log() {
        if let start = stopwatchStart {
            seconds = Date().timeIntervalSince(start).rounded()
            stopwatchStart = nil
        }
        let values = LoggedSet(type: type, weightKg: weight, reps: Int(reps.rounded()),
                               seconds: Int(seconds.rounded()))
        guard kind == .timed ? values.seconds > 0 : values.reps > 0 else { return }
        store.log(exercise: exerciseIndex, set: setIndex, values: values)
        dismiss()
    }
}

/// A number with − and + buttons. Tap the number, then turn the Digital Crown
/// for bigger steps.
struct CrownRow: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let crownStep: Double
    let buttonStep: Double
    let unit: String
    let text: (Double) -> String

    var body: some View {
        HStack(spacing: 4) {
            stepButton("minus", by: -buttonStep)
            VStack(spacing: 0) {
                Text(text(value))
                    .font(.title3.monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .focusable()
            .digitalCrownRotation($value, from: range.lowerBound, through: range.upperBound, by: crownStep,
                                  sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            stepButton("plus", by: buttonStep)
        }
    }

    private func stepButton(_ symbol: String, by delta: Double) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + delta))
        } label: {
            Image(systemName: symbol)
                .font(.body.bold())
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.gray.opacity(0.3)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
