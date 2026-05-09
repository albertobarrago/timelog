import SwiftUI
import SwiftData

struct ClientFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var client: Client?

    @State private var name = ""
    @State private var color = Color.accentColor

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client name", text: $name)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(client == nil ? "New Client" : "Edit Client")
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
                if let c = client {
                    name = c.name
                    color = c.color
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 200)
        #endif
    }

    private func save() {
        if let c = client {
            c.name = name
            c.colorHex = color.hex
        } else {
            context.insert(Client(name: name, colorHex: color.hex))
        }
        dismiss()
    }
}
