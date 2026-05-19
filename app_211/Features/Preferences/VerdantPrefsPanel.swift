import SwiftUI

struct VerdantPrefsPanel: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @Environment(\.dismiss) private var dismiss

    @State private var prefs = VerdantPrefsSnapshot.defaultValue
    @State private var showClearConfirm = false
    @State private var showResetWelcome = false

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenFoodFacts region") {
                    Picker("Database", selection: $prefs.openFoodFactsHost) {
                        ForEach(VerdantOFFRegion.allCases) { region in
                            Text(region.displayTitle).tag(region.host)
                        }
                    }
                }

                Section("Units") {
                    Toggle("Use metric units", isOn: $prefs.useMetricUnits)
                }

                Section("Data") {
                    Button("Clear product cache") {
                        try? workbench.vault.clearCache()
                    }
                    Button("Clear history") {
                        try? workbench.vault.clearHistory()
                    }
                    Button("Clear all local data", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                Section("Onboarding") {
                    Button("Show welcome again") {
                        showResetWelcome = true
                    }
                }

                Section {
                    Text("VerdantPlate uses OpenFoodFacts — an open database of food products. Product data is provided by contributors and may be incomplete.")
                        .font(.footnote)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                } header: {
                    Text("Privacy & data")
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .task {
                prefs = (try? workbench.vault.fetchPrefs()) ?? .defaultValue
            }
            .confirmationDialog("Clear all local data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear everything", role: .destructive) {
                    try? workbench.vault.clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Reset onboarding?", isPresented: $showResetWelcome, titleVisibility: .visible) {
                Button("Reset") {
                    prefs.hasCompletedWelcome = false
                    save()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        try? workbench.vault.savePrefs(prefs)
        dismiss()
    }
}
