import Charts
import SwiftUI

struct ExercisesView: View {
    @EnvironmentObject var store: Store
    @State private var search = ""
    @State private var adding = false
    @State private var newName = ""
    @State private var newKind = ExerciseKind.weighted

    private var shown: [Exercise] {
        store.library.exercises.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(shown) { exercise in
                    NavigationLink(value: exercise.id) {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text(exercise.kind.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let list = shown
                    store.deleteExercises(Set(offsets.map { list[$0].id }))
                }
            }
            .searchable(text: $search)
            .navigationTitle("Exercises")
            .navigationDestination(for: UUID.self) { ExerciseDetailView(exerciseID: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newName = ""
                        newKind = .weighted
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    Form {
                        TextField("Name", text: $newName)
                        Picker("Type", selection: $newKind) {
                            ForEach(ExerciseKind.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    .navigationTitle("New exercise")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { adding = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                store.addExercise(named: newName, kind: newKind)
                                adding = false
                            }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

enum Metric: String, CaseIterable, Identifiable {
    case weight = "Best weight"
    case e1RM = "Est. 1RM"
    case volume = "Volume"
    case reps = "Best reps"
    case seconds = "Best time"

    var id: String { rawValue }

    static func options(for kind: ExerciseKind) -> [Metric] {
        switch kind {
        case .weighted: return [.e1RM, .weight, .volume]
        case .bodyweight: return [.reps, .weight, .volume]
        case .timed: return [.seconds]
        }
    }

    var unit: String {
        switch self {
        case .weight, .e1RM, .volume: return "kg"
        case .reps: return "reps"
        case .seconds: return "sec"
        }
    }
}

/// One workout's numbers for one exercise.
struct SessionPoint: Identifiable {
    let id: UUID
    let date: Date
    let sets: [LoggedSet]
    let best: ExerciseBest
    let volume: Double

    func value(_ metric: Metric) -> Double {
        switch metric {
        case .weight: return best.weightKg
        case .e1RM: return best.e1RM
        case .volume: return volume
        case .reps: return Double(best.reps)
        case .seconds: return Double(best.seconds)
        }
    }
}

struct ExerciseDetailView: View {
    @EnvironmentObject var store: Store
    let exerciseID: UUID
    @State private var metric: Metric?

    private var index: Int? {
        store.library.exercises.firstIndex { $0.id == exerciseID }
    }

    private var sessions: [SessionPoint] {
        store.library.workouts.sorted { $0.start < $1.start }.compactMap { workout in
            let sets = workout.exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.sets).filter(\.done)
            guard !sets.isEmpty else { return nil }
            return SessionPoint(id: workout.id, date: workout.start, sets: sets, best: Stats.best(of: sets),
                                volume: sets.reduce(0) { $0 + Stats.volume(of: $1) })
        }
    }

    var body: some View {
        if let index {
            let exercise = store.library.exercises[index]
            let points = sessions
            let options = Metric.options(for: exercise.kind)
            let shownMetric = metric.flatMap { options.contains($0) ? $0 : nil } ?? options[0]
            List {
                if points.isEmpty {
                    Text("No sets logged yet.").foregroundStyle(.secondary)
                } else {
                    Section("Progress") {
                        if options.count > 1 {
                            Picker("Metric", selection: Binding(get: { shownMetric }, set: { metric = $0 })) {
                                ForEach(options) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        Chart(points) { session in
                            LineMark(x: .value("Date", session.date),
                                     y: .value(shownMetric.rawValue, session.value(shownMetric)))
                            PointMark(x: .value("Date", session.date),
                                      y: .value(shownMetric.rawValue, session.value(shownMetric)))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartYAxisLabel(shownMetric.unit)
                        .frame(height: 220)
                        .padding(.vertical, 8)
                    }
                    Section("Records") {
                        let best = store.library.best(for: exerciseID)
                        switch exercise.kind {
                        case .weighted:
                            LabeledContent("Heaviest weight", value: "\(Format.kg(best.weightKg)) kg")
                            LabeledContent("Estimated 1RM", value: "\(Format.kg(best.e1RM.rounded())) kg")
                            LabeledContent("Best set volume", value: "\(Format.kg(best.setVolume)) kg")
                            LabeledContent("Best session volume",
                                           value: "\(Format.kg(points.map(\.volume).max() ?? 0)) kg")
                        case .bodyweight:
                            LabeledContent("Most reps", value: "\(best.reps)")
                            if best.weightKg > 0 {
                                LabeledContent("Heaviest added weight", value: "\(Format.kg(best.weightKg)) kg")
                            }
                        case .timed:
                            LabeledContent("Longest", value: Format.clock(best.seconds))
                        }
                    }
                }
                Section("Settings") {
                    Picker("Type", selection: $store.library.exercises[index].kind) {
                        ForEach(ExerciseKind.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper(value: $store.library.exercises[index].restSeconds, in: 0...600, step: 15) {
                        LabeledContent("Rest timer", value: Format.clock(exercise.restSeconds))
                    }
                }
                if !points.isEmpty {
                    Section("History") {
                        ForEach(points.reversed()) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.bold())
                                Text(session.sets.map { set in
                                    (set.type.badge.map { $0 + " " } ?? "") + Format.set(set, kind: exercise.kind)
                                }.joined(separator: "\n"))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Exercise deleted", systemImage: "trash")
        }
    }
}
