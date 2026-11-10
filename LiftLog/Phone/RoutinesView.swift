import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Routine?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.library.routines) { routine in
                    Button {
                        editing = routine
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name).font(.headline)
                            Text(summary(of: routine))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { store.library.routines.remove(atOffsets: $0) }
                .onMove { store.library.routines.move(fromOffsets: $0, toOffset: $1) }
            }
            .overlay {
                if store.library.routines.isEmpty {
                    ContentUnavailableView("No routines", systemImage: "list.bullet.clipboard",
                                           description: Text("Tap + to build one, or import your Strong history from the More tab. Routines appear on your watch."))
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = Routine(name: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { RoutineEditor(routine: $0) }
        }
    }

    private func summary(of routine: Routine) -> String {
        let names = routine.items.compactMap { store.exercise($0.exerciseID)?.name }
        return names.isEmpty ? "No exercises" : names.joined(separator: ", ")
    }
}

struct RoutineEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var routine: Routine
    @State private var picking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Push day", text: $routine.name)
                }
                Section("Exercises") {
                    ForEach($routine.items) { $item in
                        Stepper(value: $item.targetSets, in: 1...12) {
                            VStack(alignment: .leading) {
                                Text(store.exercise(item.exerciseID)?.name ?? "Deleted exercise")
                                Text("\(item.targetSets) sets")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { routine.items.remove(atOffsets: $0) }
                    .onMove { routine.items.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        picking = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(routine.name.isEmpty ? "New routine" : routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        routine.name = routine.name.trimmingCharacters(in: .whitespaces)
                        store.upsert(routine)
                        dismiss()
                    }
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                ExercisePicker { routine.items.append(RoutineItem(exerciseID: $0.id)) }
            }
        }
    }
}

struct ExercisePicker: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            List(store.library.exercises.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { exercise in
                Button(exercise.name) {
                    onPick(exercise)
                    dismiss()
                }
                .tint(.primary)
            }
            .searchable(text: $search)
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
