import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var importing = false
    @State private var pounds = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        importing = true
                    } label: {
                        Label("Import Strong CSV", systemImage: "square.and.arrow.down")
                    }
                    Toggle("File weights are in pounds", isOn: $pounds)
                } header: {
                    Text("Strong")
                } footer: {
                    Text("In Strong: Profile → Settings → Export Strong Data, then save the file to Files. Importing twice does not duplicate workouts. The pounds switch only matters for exports whose weight column has no unit.")
                }

                Section {
                    LabeledContent("Status", value: store.watchStatus)
                    Button("Sync to watch now") { store.pushToWatch() }
                } header: {
                    Text("Apple Watch")
                } footer: {
                    Text("Routines, last-time values and records are sent to the watch automatically whenever something changes.")
                }

                Section("Data") {
                    LabeledContent("Workouts", value: "\(store.library.workouts.count)")
                    LabeledContent("Exercises", value: "\(store.library.exercises.count)")
                    LabeledContent("Routines", value: "\(store.library.routines.count)")
                }
            }
            .navigationTitle("More")
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                message = run(result)
            }
            .alert("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func run(_ result: Result<URL, Error>) -> String {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return "Could not read the file as text."
            }
            let summary = try store.importStrong(text, pounds: pounds)
            return "Imported \(summary.workouts) workouts (\(summary.sets) sets). "
                + "Added \(summary.newExercises) exercises and \(summary.newRoutines) routines. "
                + "Skipped \(summary.skippedDuplicates) already imported."
        } catch {
            return error.localizedDescription
        }
    }
}
