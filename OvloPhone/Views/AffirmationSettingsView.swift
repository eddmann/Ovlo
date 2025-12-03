import SwiftUI

/// Settings view for managing custom affirmations.
struct AffirmationSettingsView: View {
    @State private var affirmations: [String] = []
    @State private var newAffirmation: String = ""
    @State private var showingResetAlert = false

    var body: some View {
        List {
            Section {
                ForEach(affirmations.indices, id: \.self) { index in
                    TextField("Affirmation", text: $affirmations[index])
                        .onChange(of: affirmations[index]) { _, _ in
                            save()
                        }
                }
                .onDelete(perform: delete)
            }

            Section {
                HStack {
                    TextField("Add new...", text: $newAffirmation)
                    Button("Add") {
                        addNew()
                    }
                    .disabled(newAffirmation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if AffirmationManager.shared.hasCustomAffirmations {
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
        }
        .navigationTitle("Affirmations")
        .onAppear {
            affirmations = AffirmationManager.shared.affirmations
        }
        .alert("Reset to Defaults?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                AffirmationManager.shared.resetToDefaults()
                affirmations = AffirmationManager.shared.affirmations
            }
        } message: {
            Text("This will replace your custom affirmations with the default list.")
        }
    }

    private func addNew() {
        let trimmed = newAffirmation.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        affirmations.append(trimmed)
        newAffirmation = ""
        save()
    }

    private func delete(at offsets: IndexSet) {
        affirmations.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        AffirmationManager.shared.affirmations = affirmations.filter { !$0.isEmpty }
    }
}

#Preview {
    NavigationStack {
        AffirmationSettingsView()
    }
}
