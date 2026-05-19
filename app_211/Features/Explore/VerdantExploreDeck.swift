import SwiftUI

struct VerdantExploreDeck: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator
    @State private var query = ""
    @State private var recent: [VerdantHistoryEntry] = []

    private let quickFilters = [
        ("Vegan", "vegan"),
        ("Gluten-free", "gluten-free"),
        ("No added sugar", "no added sugar"),
    ]

    var body: some View {
        NavigationStack(path: $orchestrator.explorePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.xl) {
                    VPField(text: $query, placeholder: "Brand, product, or category", onSubmit: submitSearch)
                    Button("Search OpenFoodFacts") { submitSearch() }
                        .buttonStyle(VPPrimaryButton(enabled: query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2))
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VerdantPlateSkin.Pad.sm) {
                            ForEach(quickFilters, id: \.0) { label, q in
                                VPChip(label: label) {
                                    query = q
                                    submitSearch()
                                }
                            }
                        }
                    }

                    Button {
                        orchestrator.isLensPresented = true
                    } label: {
                        Label("Scan instead", systemImage: "qrcode.viewfinder")
                            .font(VerdantPlateSkin.TypeScale.caption)
                            .foregroundStyle(VerdantPlateSkin.Hues.primary)
                    }

                    if !recent.isEmpty {
                        Text("Recently viewed")
                            .font(VerdantPlateSkin.TypeScale.h2)
                        ForEach(recent.prefix(5)) { entry in
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
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .vpPreferencesToolbar()
            .navigationDestination(for: String.self) { barcode in
                VerdantItemDossier(barcode: barcode)
            }
            .navigationDestination(for: VerdantSearchRoute.self) { route in
                VerdantSearchRoster(query: route.query)
            }
            .task { recent = (try? workbench.vault.fetchHistory(limit: 5)) ?? [] }
        }
    }

    private func submitSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return }
        orchestrator.explorePath.append(VerdantSearchRoute(query: q))
    }
}

struct VerdantSearchRoute: Hashable {
    let query: String
}
