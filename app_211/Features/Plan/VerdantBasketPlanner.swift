import SwiftUI

struct VerdantBasketPlanner: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator
    @State private var baskets: [VerdantBasket] = []
    @State private var expandedId: UUID?

    var body: some View {
        NavigationStack(path: $orchestrator.planPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.lg) {
                    Text("Plan what you eat day by day — add products from any dossier.")
                        .font(VerdantPlateSkin.TypeScale.body)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)

                    Button {
                        addTodayBasket()
                    } label: {
                        Label("Add today", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(VPPrimaryButton())

                    if baskets.isEmpty {
                        VPEmptyCanvas(
                            icon: "calendar.badge.plus",
                            title: "No baskets yet",
                            detail: "Create a basket for today or add products from a dossier."
                        )
                    } else {
                        timeline
                    }
                }
                .padding(VerdantPlateSkin.Pad.lg)
            }
            .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .vpPreferencesToolbar()
            .navigationDestination(for: String.self) { barcode in
                VerdantItemDossier(barcode: barcode)
            }
            .task { reload() }
            .onAppear { reload() }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(baskets.enumerated()), id: \.element.id) { index, basket in
                HStack(alignment: .top, spacing: VerdantPlateSkin.Pad.md) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(VerdantPlateSkin.Hues.primary)
                            .frame(width: 12, height: 12)
                        if index < baskets.count - 1 {
                            Rectangle()
                                .fill(VerdantPlateSkin.Hues.border)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 20)

                    VStack(alignment: .leading, spacing: VerdantPlateSkin.Pad.sm) {
                        Button {
                            withAnimation(VPMotion.spring()) {
                                expandedId = expandedId == basket.id ? nil : basket.id
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(basket.title)
                                        .font(VerdantPlateSkin.TypeScale.h2)
                                        .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                                    Text("\(basket.items.count) items")
                                        .font(VerdantPlateSkin.TypeScale.caption)
                                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                                }
                                Spacer()
                                Image(systemName: expandedId == basket.id ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                            }
                        }
                        .buttonStyle(.plain)

                        if expandedId == basket.id {
                            if basket.items.isEmpty {
                                Text("Empty basket — add from a product dossier.")
                                    .font(VerdantPlateSkin.TypeScale.caption)
                                    .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                            } else {
                                ForEach(basket.items) { item in
                                    HStack(alignment: .center, spacing: VerdantPlateSkin.Pad.sm) {
                                        NavigationLink(value: item.barcode) {
                                            VPProductRowContent(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        Button {
                                            try? workbench.vault.removeFromBasket(basketId: basket.id, barcode: item.barcode)
                                            reload()
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(VerdantPlateSkin.Hues.danger)
                                        }
                                    }
                                }
                            }
                            Button("Remove basket", role: .destructive) {
                                try? workbench.vault.deleteBasket(id: basket.id)
                                reload()
                            }
                            .font(VerdantPlateSkin.TypeScale.caption)
                        }
                    }
                    .padding(VerdantPlateSkin.Pad.md)
                    .background(VerdantPlateSkin.Hues.surface)
                    .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.md, style: .continuous))
                    .vpSoftShadow()
                }
                .padding(.bottom, VerdantPlateSkin.Pad.lg)
            }
        }
    }

    private func addTodayBasket() {
        _ = try? workbench.vault.ensureBasket(for: Date())
        reload()
        if let today = baskets.first(where: { Calendar.current.isDateInToday($0.day) }) {
            expandedId = today.id
        }
    }

    private func reload() {
        baskets = (try? workbench.vault.fetchBaskets()) ?? []
    }
}
