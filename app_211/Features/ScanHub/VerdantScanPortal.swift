import SwiftUI

struct VerdantScanPortal: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator
    @State private var manualCode = ""
    @State private var recent: [VerdantHistoryEntry] = []
    @State private var lookupError: String?

    var body: some View {
        NavigationStack(path: $orchestrator.scanPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.xl) {
                    Text("Scan a barcode or QR code to open nutrition facts instantly.")
                        .font(VerdantPlateSkin.TypeScale.body)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)

                    VPScanHeroCard {
                        orchestrator.isLensPresented = true
                    }
                    manualEntry
                    if let lookupError {
                        Text(lookupError)
                            .font(VerdantPlateSkin.TypeScale.caption)
                            .foregroundStyle(VerdantPlateSkin.Hues.danger)
                    }
                    if !recent.isEmpty {
                        Text("Recent scans")
                            .font(VerdantPlateSkin.TypeScale.h2)
                            .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                        ForEach(recent.prefix(6)) { entry in
                            VPProductRowLink(item: VerdantListItem(
                                barcode: entry.barcode, name: entry.name, brand: entry.brand,
                                imageUrl: entry.imageUrl, nutriScore: entry.nutriScore,
                                energyKcal100g: nil, sugars100g: nil, salt100g: nil
                            ))
                        }
                    }
                }
                .padding(VerdantPlateSkin.Pad.lg)
            }
            .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
            .vpPreferencesToolbar()
            .navigationDestination(for: String.self) { barcode in
                VerdantItemDossier(barcode: barcode)
            }
            .task { await reloadRecent() }
            .onChange(of: orchestrator.scanPath) { _, _ in
                Task { await reloadRecent() }
            }
        }
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.sm) {
            Text("Manual barcode")
                .font(VerdantPlateSkin.TypeScale.eyebrow)
                .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
            HStack {
                TextField("Enter digits or paste OFF link", text: $manualCode)
                    .keyboardType(.numberPad)
                    .font(VerdantPlateSkin.TypeScale.body)
                Button("Look up") { submitManual() }
                    .font(VerdantPlateSkin.TypeScale.caption)
                    .foregroundStyle(VerdantPlateSkin.Hues.primary)
            }
            .padding(VerdantPlateSkin.Pad.md)
            .background(VerdantPlateSkin.Hues.surface)
            .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.md, style: .continuous)
                    .stroke(VerdantPlateSkin.Hues.border, lineWidth: 1)
            )
        }
    }

    private func submitManual() {
        lookupError = nil
        guard let code = VPScannedCodeNormalizer.canonicalProductCode(manualCode) else {
            lookupError = "Could not parse a valid product code."
            return
        }
        manualCode = ""
        orchestrator.scanPath.append(code)
    }

    private func reloadRecent() async {
        recent = (try? workbench.vault.fetchHistory(limit: 8)) ?? []
    }
}
