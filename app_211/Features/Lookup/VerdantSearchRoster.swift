import SwiftUI

struct VerdantSearchRoster: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    let query: String

    @State private var items: [VerdantListItem] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, items.isEmpty {
                VPEmptyCanvas(icon: "wifi.exclamationmark", title: "Search failed", detail: errorMessage)
            } else if items.isEmpty {
                VPEmptyCanvas(icon: "magnifyingglass", title: "No matches", detail: "Try a different search term or scan a barcode.")
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink(value: item.barcode) {
                            VPProductRowContent(item: item)
                        }
                        .listRowBackground(VerdantPlateSkin.Hues.background)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    if hasMore {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Button("Load more") { Task { await load(page: page + 1, append: true) } }
                            }
                            Spacer()
                        }
                        .listRowBackground(VerdantPlateSkin.Hues.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { barcode in
            VerdantItemDossier(barcode: barcode)
        }
        .task(id: query) {
            page = 1
            items = []
            await load(page: 1, append: false)
        }
    }

    private func load(page: Int, append: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await workbench.vault.search(query: query, page: page)
            if append {
                items.append(contentsOf: result.items)
            } else {
                items = result.items
            }
            self.page = page
            hasMore = result.hasMore
        } catch VerdantPlateError.networkUnavailable {
            errorMessage = "Check your internet connection."
        } catch {
            errorMessage = "Could not load search results."
        }
    }
}
