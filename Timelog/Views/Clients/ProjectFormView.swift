import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var client: Client
    var project: Project?

    @State private var name = ""
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project name", text: $name)
                    TextField("Code (optional)", text: $code)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = project {
                    name = p.name
                    code = p.code ?? ""
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 200)
        #endif
    }

    private func save() {
        if let p = project {
            p.name = name
            p.code = code.isEmpty ? nil : code
        } else {
            let p = Project(name: name, code: code.isEmpty ? nil : code)
            p.client = client
            context.insert(p)
        }
        dismiss()
    }
}
