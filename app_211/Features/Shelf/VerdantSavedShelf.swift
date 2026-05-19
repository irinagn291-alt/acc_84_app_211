import SwiftUI

enum VerdantShelfSegment: String, CaseIterable, Identifiable {
    case history
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: "History"
        case .favorites: "Favorites"
        }
    }
}

struct VerdantSavedShelf: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator
    @State private var segment: VerdantShelfSegment = .history
    @State private var query = ""
    @State private var history: [VerdantHistoryEntry] = []
    @State private var favorites: [VerdantListItem] = []

    var body: some View {
        NavigationStack(path: $orchestrator.shelfPath) {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    ForEach(VerdantShelfSegment.allCases) { seg in
                        Text(seg.title).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(VerdantPlateSkin.Pad.lg)

                VPField(text: $query, placeholder: "Filter shelf…")
                    .padding(.horizontal, VerdantPlateSkin.Pad.lg)
                    .padding(.bottom, VerdantPlateSkin.Pad.sm)

                Group {
                    switch segment {
                    case .history:
                        historyList
                    case .favorites:
                        favoritesList
                    }
                }
            }
            .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
            .navigationTitle("Shelf")
            .navigationBarTitleDisplayMode(.large)
            .vpPreferencesToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if segment == .history {
                        Button("Clear") { clearHistory() }
                            .font(VerdantPlateSkin.TypeScale.caption)
                    }
                }
            }
            .navigationDestination(for: String.self) { barcode in
                VerdantItemDossier(barcode: barcode)
            }
            .onChange(of: segment) { _, _ in reload() }
            .onChange(of: query) { _, _ in reload() }
            .task { reload() }
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if history.isEmpty {
            VPEmptyCanvas(
                icon: "clock.arrow.circlepath",
                title: "No history yet",
                detail: "Products you open will appear here."
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: VerdantPlateSkin.Pad.sm) {
                    ForEach(history) { entry in
                        VPProductRowLink(item: VerdantListItem(
                            barcode: entry.barcode, name: entry.name, brand: entry.brand,
                            imageUrl: entry.imageUrl, nutriScore: entry.nutriScore,
                            energyKcal100g: nil, sugars100g: nil, salt100g: nil
                        ))
                    }
                }
                .padding(VerdantPlateSkin.Pad.lg)
            }
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if favorites.isEmpty {
            VPEmptyCanvas(
                icon: "heart",
                title: "No favorites",
                detail: "Tap the heart on a product dossier to save it here."
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: VerdantPlateSkin.Pad.sm) {
                    ForEach(favorites) { item in
                        VPProductRowLink(item: item)
                    }
                }
                .padding(VerdantPlateSkin.Pad.lg)
            }
        }
    }

    private func reload() {
        history = (try? workbench.vault.fetchHistory(query: query)) ?? []
        favorites = (try? workbench.vault.fetchFavorites(query: query)) ?? []
    }

    private func clearHistory() {
        try? workbench.vault.clearHistory()
        reload()
    }
}
