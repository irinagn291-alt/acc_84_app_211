import SwiftUI

struct VerdantItemDossier: View {
    let barcode: String
    @EnvironmentObject private var workbench: VerdantWorkbench

    @State private var item: VerdantFoodItem?
    @State private var source: VerdantItemSource?
    @State private var cautions: [VerdantCaution] = []
    @State private var isFavorite = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showBasketSheet = false
    @State private var basketDay = Date()

    var body: some View {
        Group {
            if isLoading && item == nil && errorMessage == nil {
                ProgressView().tint(VerdantPlateSkin.Hues.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = errorMessage {
                VPEmptyCanvas(icon: "exclamationmark.triangle.fill", title: "No data", detail: msg)
            } else if let item {
                dossierScroll(item)
            }
        }
        .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if item != nil {
                    Button { Task { await toggleFavorite() } } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(VerdantPlateSkin.Hues.danger)
                    }
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(VerdantPlateSkin.Hues.primary)
                    }
                    Button {
                        basketDay = Date()
                        showBasketSheet = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(VerdantPlateSkin.Hues.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showBasketSheet) {
            NavigationStack {
                Form {
                    DatePicker("Day", selection: $basketDay, displayedComponents: .date)
                }
                .navigationTitle("Add to basket")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showBasketSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let item {
                                try? workbench.vault.addToBasket(day: basketDay, item: item)
                            }
                            showBasketSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task(id: barcode) { await load() }
    }

    private var shareText: String {
        guard let item else { return "Barcode: \(barcode)" }
        var lines = [item.name]
        if let b = item.brand { lines.append(b) }
        lines.append("Barcode: \(item.barcode)")
        if let u = item.url { lines.append(u) }
        return lines.joined(separator: "\n")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resolved = try await workbench.vault.fetchItem(barcode: barcode, preferNetwork: true)
            item = resolved.item
            source = resolved.source
            cautions = workbench.cautionEngine.evaluate(item: resolved.item)
            isFavorite = (try? workbench.vault.isFavorite(barcode: barcode)) ?? false
        } catch VerdantPlateError.itemNotFound {
            errorMessage = "Product not found in OpenFoodFacts."
        } catch VerdantPlateError.networkUnavailable {
            errorMessage = "Could not load data. Check your connection."
        } catch {
            errorMessage = "Could not load product."
        }
    }

    private func toggleFavorite() async {
        guard let item else { return }
        isFavorite = (try? workbench.vault.toggleFavorite(item: item)) ?? isFavorite
    }

    @ViewBuilder
    private func dossierScroll(_ item: VerdantFoodItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.lg) {
                hero(item)
                if source == .cacheWhenOffline {
                    Label("Offline cached copy", systemImage: "wifi.slash")
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.warning)
                }
                VPScoreStrip(item: item)
                if !cautions.isEmpty {
                    VStack(spacing: VerdantPlateSkin.Pad.sm) {
                        ForEach(cautions) { VPCautionBanner(caution: $0) }
                    }
                }
                nutritionGrid(item.nutriments)
                if let text = item.ingredientsText, !text.isEmpty {
                    section("Ingredients", text)
                }
                if !item.allergens.isEmpty {
                    tagSection("Allergens", item.allergens)
                }
                if !item.additives.isEmpty {
                    tagSection("Additives", item.additives)
                }
                if !item.categories.isEmpty {
                    tagSection("Categories", item.categories)
                }
            }
            .padding(VerdantPlateSkin.Pad.lg)
        }
    }

    private func hero(_ item: VerdantFoodItem) -> some View {
        HStack(alignment: .top, spacing: VerdantPlateSkin.Pad.lg) {
            VPRemoteThumb(urlString: item.imageUrl, size: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(VerdantPlateSkin.TypeScale.h1)
                    .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                if let brand = item.brand {
                    Text(brand)
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                if let qty = item.quantity {
                    Text(qty)
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                Text(item.barcode)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
            }
        }
        .padding(VerdantPlateSkin.Pad.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
        .vpCardShadow()
    }

    private func nutritionGrid(_ n: VerdantNutriments) -> some View {
        VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.sm) {
            Text("Nutrition per 100g")
                .font(VerdantPlateSkin.TypeScale.h2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VerdantPlateSkin.Pad.sm) {
                nutrientCell("Energy", n.energyKcal100g, "kcal")
                nutrientCell("Protein", n.proteins100g, "g")
                nutrientCell("Fat", n.fat100g, "g")
                nutrientCell("Sat. fat", n.saturatedFat100g, "g")
                nutrientCell("Carbs", n.carbohydrates100g, "g")
                nutrientCell("Sugars", n.sugars100g, "g")
                nutrientCell("Fiber", n.fiber100g, "g")
                nutrientCell("Salt", n.salt100g, "g")
            }
        }
        .padding(VerdantPlateSkin.Pad.lg)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
        .vpSoftShadow()
    }

    private func nutrientCell(_ label: String, _ value: Double?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(VerdantPlateSkin.TypeScale.caption)
                .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
            Text(value.map { String(format: "%.1f %@", $0, unit) } ?? "—")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VerdantPlateSkin.Pad.sm)
        .background(VerdantPlateSkin.Hues.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.sm, style: .continuous))
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.sm) {
            Text(title).font(VerdantPlateSkin.TypeScale.h2)
            Text(body).font(VerdantPlateSkin.TypeScale.body).foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
        }
        .padding(VerdantPlateSkin.Pad.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
        .vpSoftShadow()
    }

    private func tagSection(_ title: String, _ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.sm) {
            Text(title).font(VerdantPlateSkin.TypeScale.h2)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(chunked(tags, size: 3), id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { tag in
                            Text(tag)
                                .font(VerdantPlateSkin.TypeScale.caption)
                                .foregroundStyle(VerdantPlateSkin.Hues.primaryDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VerdantPlateSkin.Hues.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(VerdantPlateSkin.Pad.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
        .vpSoftShadow()
    }

    private func chunked(_ array: [String], size: Int) -> [[String]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0 ..< min($0 + size, array.count)])
        }
    }
}
