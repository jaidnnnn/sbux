import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store

    private var workouts: [Workout] {
        store.library.workouts.sorted { $0.start > $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    NavigationLink(value: workout.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name).font(.headline)
                            Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(facts(about: workout))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let shown = workouts
                    store.deleteWorkouts(Set(offsets.map { shown[$0].id }))
                }
            }
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock",
                                           description: Text("Workouts you finish on your watch show up here."))
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { WorkoutDetailView(workoutID: $0) }
        }
    }

    private func facts(about workout: Workout) -> String {
        let sets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        return "\(Format.duration(workout.duration)) · \(sets) sets · \(Format.kg(Stats.volume(of: workout).rounded())) kg"
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var store: Store
    let workoutID: UUID

    var body: some View {
        List {
            if let workout = store.library.workouts.first(where: { $0.id == workoutID }) {
                Section {
                    LabeledContent("Date", value: workout.start.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Duration", value: Format.duration(workout.duration))
                    LabeledContent("Volume", value: "\(Format.kg(Stats.volume(of: workout).rounded())) kg")
                    if !workout.notes.isEmpty { Text(workout.notes) }
                }
                ForEach(workout.exercises) { exercise in
                    Section(exercise.name) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            SetLine(number: index + 1, set: set, kind: exercise.kind)
                        }
                    }
                }
            }
        }
        .navigationTitle(store.library.workouts.first { $0.id == workoutID }?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SetLine: View {
    let number: Int
    let set: LoggedSet
    let kind: ExerciseKind

    var body: some View {
        HStack {
            Text(set.type.badge ?? "\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(set.type == .normal ? Color.secondary : Color.orange)
                .frame(width: 24, alignment: .leading)
            Text(Format.set(set, kind: kind)).monospacedDigit()
            Spacer()
            if kind == .weighted, set.type != .warmup {
                Text("1RM \(Format.kg(Stats.e1RM(weightKg: set.weightKg, reps: set.reps).rounded()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
